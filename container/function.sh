#!/usr/bin/env bash
#set -x

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
description="https://gitHub.com/EGMSystems/sh"
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

varToCamelCase() {
    local underScoreAndHyphenToUpperCase=$(echo $1 | sed 's/_/-/g')
    local toUpperCaseFirstLetter=$(echo $underScoreAndHyphenToUpperCase | sed 's/\([a-z]\)_\([a-z]\)/\1\U\2/g' | sed 's/\([a-z]\)-\([a-z]\)/\1\U\2/g')
    echo ${toUpperCaseFirstLetter^}
}

camelCaseToTitleCase() {
    echo $1 | sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g'
}

varToTitleCase() {
    echo $(camelCaseToTitleCase $(varToCamelCase $1))
}

bashStart() {
    set -e
    chmod +x $0
    print_info $(varToTitleCase $(basename "$0" .sh))
    echo "v$1"
    echo ""
}

validate_input() {
    print_info "validate_input $CONTAINER_ID..."
    if ! command -v pct &> /dev/null; then
        print_error "pct command not found. This script must be run on a Proxmox VE node."
        exit 1
    fi

    if pct status "$CONTAINER_ID" &> /dev/null; then
        print_error "Container ID $CONTAINER_ID already exists."
        exit 1
    fi
    
    if [ "$(basename $0 .sh)" != "pve_createContainer-${hostname}" ]; then
        print_error "$0 != pve_createContainer-${hostname}"
        exit 1
    fi
    print_info "... $CONTAINER_ID validate_input"
}

create_container() {
    print_info "create_container $CONTAINER_ID..."

    if [ -n "$hwaddr" ]; then
        hwaddr=",hwaddr=$hwaddr"
    fi
    if [ "${IP_Config,,}" = "dhcp" ]; then
        net0="name=eth0,bridge=vmbr0$hwaddr,ip=dhcp"
    else
        net0="name=eth0,bridge=vmbr0$hwaddr,ip=${IP_Config}/24,gw=${GATEWAY}"
    fi

    local pct_create=$(cat <<EOF
pct create \
    $CONTAINER_ID \
    $ostemplate \
    --storage $storage \
    --rootfs ${storage}:${DISK_SIZE} \
    --hostname $hostname \
    --cores $cores \
    --memory $memory \
    --swap $swap \
    --unprivileged $unprivileged \
    --net0 $net0 \
    --ostype $ostype \
    --timezone $timezone \
    --description "$description" \
    --features $features
EOF
    )
    echo $pct_create
    $pct_create
    
    print_info "... create_container $CONTAINER_ID"
}

wait_container() {
    print_info "wait_container..."
    while true; do
        if pct status "$CONTAINER_ID" | grep -q "running"; then
            break
        fi
        sleep 1
    done
    print_info "...wait_container"
}

wait_IP_Config() {
    print_info "wait_IP_Config..."
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
    print_info "...wait_IP_Config"
}

wait_IP_internet() {
    print_info "...wait_IP_internet"
    while ! pct exec "$CONTAINER_ID" -- ping -c 2 "8.8.8.8"; do
        print_warn "ping 8.8.8.8 bad, witing 1s to try ..."
        sleep 1
    done
    print_info "...wait_IP_internet"
}

send_start(){
    print_info "send_start $CONTAINER_ID..."
    pct start "$CONTAINER_ID"
    print_info "sended."
}

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

set_root_password() {
    if [ -n "$ROOT_PASSWORD" ]; then
        print_info "Setting root password inside container..."
        pct exec "$CONTAINER_ID" -- bash -c "echo 'root:${ROOT_PASSWORD}' | chpasswd" || print_warn "Failed to set root password"
    fi
}

configure_apt_cacher() {
    if [ -z "$APT_CACHER" ]; then
        print_info "configure_apt_cacher not set, skipping apt-cacher-ng configuration"
        return
    fi
    if [ $ostype == "alpine" ] ; then
        print_info "configure_apt_cacher not work yet with $ostype"
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

upDateGrading() {
    print_info "upDateGrading..."
    pct exec "$CONTAINER_ID" -- apt -y update
    print_info "...updated, upgrading..."
    pct exec "$CONTAINER_ID" -- apt -y upgrade
    print_info "...upDateGrading"
}

reBoot() {
    print_info "reBoot CONTAINER_ID: $CONTAINER_ID ..."
    pct reboot "$CONTAINER_ID"
}

show_summary() {
    echo ""
    echo "========================================"
    print_info "show_summary!"
    echo "========================================"
    echo "Container ID:    $CONTAINER_ID"
    echo "hostname:        $hostname"
    echo "cores:           $cores"
    echo "IP Address:      $IP_Config"
    echo "memory:          ${memory}MB"
    echo "swap:            ${swap}MB"
    echo "storage:         $storage"
    echo "vztmpl:          $vztmpl"
    echo "OS Type:         $ostype"
    echo "ostemplate:      $ostemplate"
    echo "Disk:            ${DISK_SIZE}GB"
    echo "unprivileged:    $unprivileged"
    echo "timezone:        $timezone"
    echo "description:     $description"
    echo "features:        $features"
    echo "========================================"
    echo ""
}
