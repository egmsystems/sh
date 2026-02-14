#!/usr/bin/env bash
set -e
CONTAINER_ID=$(pvesh get /cluster/nextid)
CONTAINER_NAME=${2:-iventoy}
HOSTNAME="${CONTAINER_NAME}"
IP_ADDRESS="dhcp"
GATEWAY=""                     # Gateway IP (leave empty for DHCP)
DISK_SIZE="2"                 # Disk size in GB
MEMORY="512"                   # Memory in MB
CORES=1                        # CPU cores
STORAGE="ssd1"                 # Storage backend
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
    print_info "Creating LXC container..."
    
    if [ "${IP_ADDRESS,,}" = "dhcp" ]; then
        NETCFG="name=eth0,bridge=vmbr0,ip=dhcp"
    else
        NETCFG="name=eth0,bridge=vmbr0,ip=${IP_ADDRESS}/24,gw=${GATEWAY}"
    fi
    # Optional extra flags (uncomment or set EXTRA_FLAGS variable):
    EXTRA_FLAGS="--swap 512 --unprivileged 1" #--start 1 --onboot 1

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
        IV_VERSION="1.0.21" # Change to desired version
        mkdir -p /opt /tmp
        wget -qO /tmp/iventoy.tar.gz https://github.com/ventoy/PXE/releases/download/v${IV_VERSION}/iventoy-${IV_VERSION}-linux-free.tar.gz
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
        cd /opt/iVentoy
        #python3 -m pip install -r requirements.txt
        chmod +x ./iventoy.sh
    '
    
    print_info "iVentoy installed in /opt/iVentoy"
}

create_service() {
    print_info "create_service..."
    
    pct exec "$CONTAINER_ID" -- bash -c 'cat > /etc/systemd/system/iventoy.service << EOF
[Unit]
Description=iVentoy PXE Boot Server
Documentation=https://iventoy.com
After=network.target

[Service]
#Type=forking
Type=simple
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
'
    
    pct exec "$CONTAINER_ID" -- systemctl daemon-reload
    pct exec "$CONTAINER_ID" -- systemctl enable iventoy.service
    pct exec "$CONTAINER_ID" -- systemctl start iventoy.service
    
    print_info "iVentoy service created and enabled."
}

# Enable root auto-login on the container console (tty1)
enable_console_autologin() {
    print_info "enable_console_autologin (root) on tty1 CONTAINER_ID: $CONTAINER_ID ..."
    pct exec "$CONTAINER_ID" -- bash -c "set -e
mkdir -p /etc/systemd/system/container-getty@1.service.d
cat > /etc/systemd/system/container-getty@1.service.d/override.conf <<'EOF'
[Service]
  ExecStart=
  ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%I 115200,38400,9600 $TERM
EOF
systemctl daemon-reload || true
systemctl enable getty@tty1 || true
systemctl restart getty@tty1 || true
#systemctl status getty@tty1 || true"
    print_info "Console auto-login enabled."
}

# Show summary
show_summary() {
    print_info "Container creation completed!"
    echo ""
    echo "========================================"
    echo "Container Details:"
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
    create_service
    echo pct set "$CONTAINER_ID" -mp0 /mnt/pve/sdd1/template/iso,mp=/opt/iVentoy/iso,ro=1
    pct set "$CONTAINER_ID" -mp0 /mnt/pve/sdd1/template/iso,mp=/opt/iVentoy/iso,ro=1
    show_summary
    echo "pct stop $CONTAINER_ID ; pct destroy $CONTAINER_ID"
}

main