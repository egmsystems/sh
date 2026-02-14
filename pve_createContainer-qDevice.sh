#!/usr/bin/env bash
set -e
CONTAINER_ID=$(pvesh get /cluster/nextid)
## Default container name: use the script filename (without .sh). Allow override via $2
# Use BASH_SOURCE for robustness when the script is sourced or executed
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}" .sh)
SCRIPT_NAME="${SCRIPT_NAME#pve_createContainer-}"
SCRIPT_NAME=$(echo "$SCRIPT_NAME" | sed 's/[^A-Za-z0-9-]/-/g')
CONTAINER_NAME=${2:-$SCRIPT_NAME}

HOSTNAME="${CONTAINER_NAME}"
IP_Config="dhcp"
MAC=""                      # Optional MAC address (leave empty for random) - format: 02:xx:xx:xx:xx:xx (02 for locally administered)
GATEWAY=""                     # Gateway IP (leave empty for DHCP)
DISK_SIZE="2"                  # Disk size in GB
MEMORY="512"                   # Memory in MB
CORES=1                        # CPU cores
STORAGE="sdd1"                 # Storage backend
OS_TYPE="debian"               # OS type
OS_VERSION="13"                # OS version
OS_VERSION="sdd1:vztmpl/$OS_TYPE-${OS_VERSION}-standard_${OS_VERSION}.1-2_amd64.tar.zst"
APT_CACHER="192.168.50.78:3142" # apt-cacher-ng host[:port] (empty to disable). Example: 10.0.0.2:3142

# Root password: can be provided via env `ROOT_PASSWORD` or prompted interactively
ROOT_PASSWORD="${ROOT_PASSWORD:-}"
if [ -z "$ROOT_PASSWORD" ] && [ -t 0 ]; then
    read -s -p "Enter root password for the container: " ROOT_PASSWORD
    echo
fi

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
    if [ "${IP_Config,,}" = "dhcp" ]; then
        NETCFG="name=eth0,bridge=vmbr0$MAC,ip=dhcp"
    else
        NETCFG="name=eth0,bridge=vmbr0$MAC,ip=${IP_Config}/24,gw=${GATEWAY}"
    fi
    echo $NETCFG;
    # Optional extra flags (uncomment or set EXTRA_FLAGS variable):
    EXTRA_FLAGS="--swap 512" #--start 1 --onboot 1
    EXTRA_FLAGS="$EXTRA_FLAGS --unprivileged 1"

    pct create "$CONTAINER_ID" \
        "$OS_VERSION" \
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

configure_apt_cacher() {
    if [ -z "$APT_CACHER" ]; then
        print_info "configure_apt_cacher not set, skipping apt-cacher-ng configuration"
        return
    fi
    if [ $OS_TYPE == "alpine" ] ; then
        print_info "configure_apt_cacher not work yet with $OS_TYPE"
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

Installing_dependencies() {
    print_info "Installing_dependencies..."
    pct exec "$CONTAINER_ID" -- cat /etc/ssh/sshd_config | grep PermitRootLogin
    pct exec "$CONTAINER_ID" -- sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config || true
    pct exec "$CONTAINER_ID" -- cat /etc/ssh/sshd_config | grep PermitRootLogin
    pct exec "$CONTAINER_ID" -- systemctl restart sshd
}

install_app() {
    print_info "install_app ..."
    pct exec "$CONTAINER_ID" -- apt -y install corosync-qnetd
    print_info "app installed"
}

create_service() {
    print_info "create_service..."

    pct exec "$CONTAINER_ID" -- sh -c 'cat <<EOF > /etc/systemd/system/coroSync.service
[Unit]
Description=coroSync Quorum Device
Documentation=https://github.com/corosync/corosync
After=network.target

[Service]
#User=root
#Type=simple
Type=forking
WorkingDirectory=/root
ExecStart=/root/coroSync.sh -R start
ExecStop=/root/coroSync.sh stop
PIDFile=/var/run/coroSync.pid
Restart=on-failure
#Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
'
    pct exec "$CONTAINER_ID" -- systemctl enable -q --now coroSync.service
    print_info "service created and enabled."
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
    echo "IP Address:      $IP_Config"
    echo "Memory:          ${MEMORY}MB"
    echo "Disk:            ${DISK_SIZE}GB"
    echo "========================================"
    echo ""
}

send_start(){
    print_info "send_start $CONTAINER_ID..."
    time pct start "$CONTAINER_ID"
    print_info "sended."
}

Updating() {
    print_info "Updating system packages..."
    pct exec "$CONTAINER_ID" -- apt -y update
    print_info "upgrading system packages..."
    pct exec "$CONTAINER_ID" -- apt -y upgrade
    print_info "upgraded $CONTAINER_ID..."
}

main() {
    print_info "PVE LXC Container Creation Script"
    echo v0.0.1
    echo ""

    validate_input
    create_container
    send_start
    if [ "${IP_Config,,}" = "dhcp" ]; then
        while true; do
            IP_ADDRESS=$(lxc-info -n "$CONTAINER_ID" -i | awk '{print $2}')
            if [ -z "$IP_ADDRESS" ]; then
                echo "empty IP_ADDRESS, waiting 1s to try ..."
                sleep 1
            else 
                echo "Got IP: $IP_ADDRESS"
                break 
            fi
        done
    else
        IP_ADDRESS="$IP_Config"
    fi
    while ! pct exec "$CONTAINER_ID" -- ping -c 2 "8.8.8.8"; do
        print_warn "ping 8.8.8.8 bad, witing 1s to try ..."
        sleep 1
    done
    # If a root password was provided/prompted, set it inside the container
    if [ -n "$ROOT_PASSWORD" ]; then
        print_info "Setting root password inside container..."
        pct exec "$CONTAINER_ID" -- bash -c "echo 'root:${ROOT_PASSWORD}' | chpasswd" || print_warn "Failed to set root password"
    fi
    Updating
    enable_console_autologin
    Installing_dependencies
    install_app
    print_info "reBoot" ; pct reboot "$CONTAINER_ID"
    #create_service
    show_summary
    print_info "executing: apt -y install corosync-qdevice"
    apt -y install corosync-qdevice
    print_info "executing: pvecm qdevice setup $IP_ADDRESS -f"
    pvecm qdevice setup "$IP_ADDRESS"
}
main