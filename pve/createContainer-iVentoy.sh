#!/usr/bin/env bash
set -e
source "$( cd -- "$( dirname -- $0 )" &> /dev/null && pwd )/../function.sh"
hostname=$(basename $0 .sh)
hostname="${hostname#createContainer-}"
IP_Config="dhcp"
hwaddr="BC:24:11:76:FC:38"
GATEWAY=""                     # Gateway IP (leave empty for DHCP)
DISK_SIZE="1"                 # Disk size in GB
memory="128"                   # Memory in MB
swap=$((memory/2))
unprivileged=0
timezone="host"
features="keyctl=0,nesting=1" #--start 1 --onboot 1 # WARN: Systemd 257 detected. You may need to enable nesting.
cores=1                        # CPU cores
storage="ssd1"
vztmpl="ssd1_directory"
ostype="debian"               # OS type
ostemplate="13"                # Debian version
ostemplate="${vztmpl}:vztmpl/$ostype-${ostemplate}-standard_${ostemplate}.1-2_amd64.tar.zst"
APT_CACHER="192.168.50.78:3142" # apt-cacher-ng host[:port] (empty to disable)
APT_CACHER_ID=100

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

Installing_dependencies() {
    print_info "$(varToTitleCase ${FUNCNAME[0]}) $1 ..."
    pct exec "$1" -- apt-get install -y \
        curl \
        wget \
        git \
        python3 \
        python3-pip \
        build-essential \
        libfuse-dev \
        zlib1g-dev \
        unzip
    print_info "... $1 $(varToTitleCase ${FUNCNAME[0]})"
}

install_app() {
    print_info "$(varToTitleCase ${FUNCNAME[0]}) $1 ..."
    local VERSION=$(curl_github_latest_version "ventoy/PXE")
    pct exec $1 -- bash <<pct_exec
mkdir -p /opt /tmp
wget -qO /tmp/iventoy.tar.gz https://github.com/ventoy/PXE/releases/download/v$VERSION/iventoy-$VERSION-linux-free.tar.gz
pct_exec
    pct exec $1 -- bash <<'pct_exec'
tar -xzf /tmp/iventoy.tar.gz -C /opt
EXDIR=$( (tar -tzf /tmp/iventoy.tar.gz 2>/dev/null || true) | sed "s|^\./||" | grep -v "^$" | head -n1 | cut -f1 -d"/")
if [ -n "$EXDIR" ] && [ -d "/opt/$EXDIR" ]; then
    mv "/opt/$EXDIR" /opt/iVentoy || true
else
    D=$(ls -1 /opt | grep -i iventoy | head -n1 || true)
    if [ -n "$D" ]; then
        mv "/opt/$D" /opt/iVentoy || true
    fi
fi
chmod +x /opt/iVentoy/iventoy.sh
#python3 -m pip install -r requirements.txt # ToDo: check
pct_exec
    print_info "... $1 $(varToTitleCase ${FUNCNAME[0]})"
}

systemctl_enable_start() {
    print_info "$(varToTitleCase ${FUNCNAME[0]}) $1 ..."
    pct exec $1 -- bash <<pct_exec
cat > /etc/systemd/system/iventoy.service << EOF
[Unit]
Description=iVentoy PXE Boot Server
Documentation=https://iventoy.com
After=network.target

[Service]
Type=forking
#Type=simple
#User=root
WorkingDirectory=/opt/iVentoy
ExecStart=/opt/iVentoy/iventoy.sh start
ExecStop=/opt/iVentoy/iventoy.sh stop
Environment=IVENTOY_AUTO_RUN=1
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
cat /etc/systemd/system/iventoy.service
systemctl daemon-reload
systemctl enable iventoy.service
systemctl start iventoy.service
echo systemctl status iventoy.service
echo systemctl stop iventoy.service ; systemctl disable iventoy.service ; rm /etc/systemd/system/iventoy.service ; systemctl daemon-reload ; systemctl status iventoy.service
pct_exec
    print_info "... $1 $(varToTitleCase ${FUNCNAME[0]})"
}

main() {
    bashStart "0.0.1"
    CONTAINER_ID=$(pvesh get /cluster/nextid)
    validate_input
    time create_container
    time pct_start $CONTAINER_ID
    time pct_status_running $CONTAINER_ID
    container-getty_autologin $CONTAINER_ID
    time wait_IP_ADDRESS $IP_Config $CONTAINER_ID
    time configure_apt_cacher $APT_CACHER $APT_CACHER_ID
    time upDateGradeRemoving $CONTAINER_ID
    time Installing_dependencies $CONTAINER_ID
    time install_app $CONTAINER_ID
    time systemctl_enable_start $CONTAINER_ID
    pct set "$CONTAINER_ID" -mp0 /ssd1/directory/template/iso,mp=/opt/iVentoy/iso,ro=1
    show_summary
    echo "CONTAINER_ID=$CONTAINER_ID ; "'pct stop $CONTAINER_ID ; pct destroy $CONTAINER_ID'
}

main