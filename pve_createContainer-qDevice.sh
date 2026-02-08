#!/usr/bin/env bash
set -e
CONTAINER_ID=$(pvesh get /cluster/nextid)
## Default container name: use the script filename (without .sh). Allow override via $2
# Use BASH_SOURCE for robustness when the script is sourced or executed
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}" .sh)
# sanitize: lowercase and replace invalid chars with '-'; allow a-z0-9 and hyphen
SANITIZED_NAME=$(echo "$SCRIPT_NAME" | sed 's/[^a-z0-9-]/-/g')
CONTAINER_NAME=${2:-$SANITIZED_NAME}
echo "Container Name: $CONTAINER_NAME"
exit
HOSTNAME="${CONTAINER_NAME}"
VLAN_ID=0
IP_ADDRESS="dhcp"
MAC="bc:24:11:76:fc:38"
GATEWAY=""                     # Gateway IP (leave empty for DHCP)
DISK_SIZE="2"                  # Disk size in GB
MEMORY="512"                   # Memory in MB
CORES=1                        # CPU cores
STORAGE="sdd1"                 # Storage backend
OS_TYPE="debian"               # OS type
OS_VERSION="13"                # Debian version
APT_CACHER="192.168.50.78:3142" # apt-cacher-ng host[:port] (empty to disable). Example: 10.0.0.2:3142

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

# Validation
validate_input() {
    if ! command -v pct &> /dev/null; then
        print_error "pct command not found. This script must be run on a Proxmox VE node."
        exit 1
    fi
    
    if pct status "$CONTAINER_ID" &> /dev/null; then
        print_error "Container ID $CONTAINER_ID already exists."
        exit 1
    fi
}

create_container() {
    print_info "create_container $CONTAINER_ID..."
    
    if [ -n "$MAC" ]; then
        MAC=",hwaddr=$MAC"
    fi
    if [ "${IP_ADDRESS,,}" = "dhcp" ]; then
        NETCFG="name=eth0,bridge=vmbr0$MAC,ip=dhcp"
    else
        NETCFG="name=eth0,bridge=vmbr0$MAC,ip=${IP_ADDRESS}/24,gw=${GATEWAY}"
    fi
    # Optional extra flags (uncomment or set EXTRA_FLAGS variable):
    EXTRA_FLAGS="--swap 512" #--start 1 --onboot 1
    EXTRA_FLAGS="$EXTRA_FLAGS --unprivileged 0"

    pct create "$CONTAINER_ID" \
        "sdd1:vztmpl/debian-${OS_VERSION}-standard_${OS_VERSION}.1-2_amd64.tar.zst" \
        --cores "$CORES" \
        --memory "$MEMORY" \
        --storage "$STORAGE" \
        --rootfs "${STORAGE}:${DISK_SIZE}" \
        --net0 "${NETCFG}" \
        --ostype "$OS_TYPE" \
        --features "nesting=1,keyctl=1" \
        --timezone 'host' \
        --hostname "$HOSTNAME" \
        ${EXTRA_FLAGS:-}

    #echo "lxc.mount.entry = /sys/class/dmi/id sys/class/dmi/id none ro,bind,create=dir >> /etc/pve/lxc/$CONTAINER_ID.conf"
    #echo "lxc.mount.entry = /sys/devices/virtual/dmi/id sys/devices/virtual/dmi/id none ro,bind,create=dir" >> /etc/pve/lxc/${CONTAINER_ID}.conf
    #echo "lxc.mount.entry = /sys/devices/virtual/dmi/id /root/data/sys/class/dmi/id none ro,bind,create=dir" >> /etc/pve/lxc/${CONTAINER_ID}.conf

    print_info "Container $CONTAINER_ID created successfully."
}

Installing_dependencies() {    
    print_info "Installing_dependencies..."
    pct exec "$CONTAINER_ID" -- apt-get install -y \
        curl \
        wget \
        git \
        python3 \
        python3-pip \
        build-essential \
        libfuse-dev \
        zlib1g-dev \
        unzip
}

configure_apt_cacher() {
    if [ -z "$APT_CACHER" ]; then
        print_info "configure_apt_cacher not set, skipping apt-cacher-ng configuration"
        return
    fi

    # sanitize value: strip any http:// or https:// prefix if present
    local proxy="$APT_CACHER"
    proxy=${proxy#http://}
    proxy=${proxy#https://}

    print_info "configure_apt_cacher at $proxy"
    pct exec "$CONTAINER_ID" -- bash -c "mkdir -p /etc/apt/apt.conf.d && echo 'Acquire::http::Proxy \"http://$proxy\";' > /etc/apt/apt.conf.d/01proxy"
    # Optionally configure https to go through apt-cacher-ng via apt-transport-https wrappers if needed
}

install_iventoy() {
    print_info "install_iventoy ..."
    
    pct exec "$CONTAINER_ID" -- bash -c '
        set -e
        RELEASE=$(curl -s https://api.github.com/repos/ventoy/pxe/releases/latest | grep "tag_name" | awk "{print substr(\$2, 3, length(\$2)-4) }")
        echo "version: $RELEASE"
        mkdir -p /root/{data,iso}
        cd /tmp
        wget -q https://github.com/ventoy/PXE/releases/download/v${RELEASE}/iventoy-${RELEASE}-linux-free.tar.gz
        tar -C /tmp -xzf iventoy*.tar.gz
        rm -rf /tmp/iventoy*.tar.gz
        mv /tmp/iventoy*/* /root/
        cd /root
        #python3 -m pip install -r requirements.txt
        chmod +x ./iventoy.sh
    '
    
    print_info "iVentoy installed in /root"
}

create_service() {
    print_info "create_service..."
    
    pct exec "$CONTAINER_ID" -- bash -c 'cat <<EOF >/etc/systemd/system/iventoy.service
[Unit]
Description=iVentoy PXE Boot Server
Documentation=https://iventoy.com
After=network.target

[Service]
#User=root
#Type=simple
Type=forking
WorkingDirectory=/root
ExecStart=/root/iventoy.sh -R start
ExecStop=/root/iventoy.sh stop
PIDFile=/var/run/iventoy.pid
Environment=IVENTOY_AUTO_RUN=1
Environment=IVENTOY_API_ALL=1
Environment=LIBRARY_PATH=/root/lib/lin64
Environment=LD_LIBRARY_PATH=/root/lib/lin64
Restart=on-failure
#Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
'
    pct exec "$CONTAINER_ID" -- systemctl enable -q --now iventoy.service
    print_info "iVentoy service created and enabled."
}

# Enable root auto-login on the container console (tty1)
enable_console_autologin() {
    print_info "enable_console_autologin (root) on tty1 CONTAINER_ID: $CONTAINER_ID ..."
    pct exec "$CONTAINER_ID" -- bash -c "set -e
mkdir -p /etc/systemd/system/container-getty@1.service.d
echo '[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%I 115200,38400,9600 \$TERM' > /etc/systemd/system/container-getty@1.service.d/override.conf
systemctl daemon-reload || true
systemctl enable getty@tty1 || true
systemctl restart getty@tty1 || true
#systemctl status getty@tty1 || true
cat /etc/systemd/system/container-getty@1.service.d/override.conf"
    print_info "Console auto-login enabled."
}

# Show summary
show_summary() {
    echo ""
    echo "========================================"
    print_info "show_summary!"
    echo "========================================"
    echo "Container ID:    $CONTAINER_ID"
    echo "Name:            $CONTAINER_NAME"
    echo "Hostname:        $HOSTNAME"
    echo "IP Address:      $IP_ADDRESS"
    echo "Memory:          ${MEMORY}MB"
    echo "Disk:            ${DISK_SIZE}GB"
    echo "========================================"
    echo ""
    if [ "${IP_ADDRESS,,}" = "dhcp" ]; then
        IP_ADDRESS=$(pct exec "$CONTAINER_ID" -- hostname -I | awk '{print $1}')
    fi
    print_info "Access iVentoy at: http://${IP_ADDRESS}:26000"
    echo ""
}

starting() {
    print_info "starting $CONTAINER_ID..."
    pct start "$CONTAINER_ID"
    configure_apt_cacher
    print_info "Updating system packages..."
    pct exec "$CONTAINER_ID" -- apt -y update
    print_info "upgrading system packages..."
    pct exec "$CONTAINER_ID" -- apt -y upgrade
}

main() {
    print_info "PVE iVentoy LXC Container Creation Script"
    echo v0.0.1
    echo Creates a lightweight iVentoy container for ISO/image management on Proxmox VE
    echo ""
    
    validate_input
    create_container
    starting
    enable_console_autologin
    Installing_dependencies
    install_iventoy
    echo pct set "$CONTAINER_ID" -mp0 /mnt/pve/sdd1/template/iso,mp=/root/iso,ro=1
    pct set "$CONTAINER_ID" -mp0 /mnt/pve/sdd1/template/iso,mp=/root/iso,ro=1
    #pct set "$CONTAINER_ID" -mp1 /sys/devices/virtual/dmi/id,mp=/root/data/sys/class/dmi/id,ro=1
    #print_info "reBoot."
    #pct reboot "$CONTAINER_ID"
    create_service
    show_summary
    pct push "$CONTAINER_ID" pve_createContainer-iVentoy/unattended.xml /root/user/scripts/example/unattended.xml
    pct push "$CONTAINER_ID" pve_createContainer-iVentoy/windows_injection.7z /root/user/scripts/example/windows_injection.7z
    pct exec "$CONTAINER_ID" -- /root/iventoy.sh status
    echo pct exec "$CONTAINER_ID" -- /root/iventoy.sh -R start
    pct exec "$CONTAINER_ID" -- /root/iventoy.sh status
    cat /root/log/log.txt
    echo "pct stop $CONTAINER_ID ; pct destroy $CONTAINER_ID"
    pct exec "$CONTAINER_ID" -- ls -all /sys/class/dmi/id ; ls /sys/class/dmi/id ; cat /sys/class/dmi/id/product_uuid
}
main