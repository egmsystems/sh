#!/usr/bin/env bash
#set -x
#source /home/sh/function.sh
environment=0

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
    if [ $environment -eq 0 ]; then
        echo $1
    else
        echo $(camelCaseToTitleCase $(varToCamelCase $1))
    fi
}

bashStart() {
    chmod +x $0
    print_info $(varToTitleCase $(basename "$0" .sh))
    echo "v$1"
    echo ""
}

input() {
    local var_name="${2:-REPLY}"
    read $3 -p "$1: " $var_name
    eval "echo \$$var_name"
}

validate_input() {
    print_info "$(varToTitleCase ${FUNCNAME[0]}) ..."
    if ! command -v pct &> /dev/null; then
        print_error "pct command not found. This script must be run on a Proxmox VE node."
        exit 1
    fi

    if pct status $CONTAINER_ID; then
        print_error "Container ID $CONTAINER_ID already exists."
        exit 1
    fi
    
    if [ "$(basename $0 .sh)" != "createContainer-$hostname" ]; then
        print_error "$0 != createContainer-$hostname"
        exit 1
    fi
    print_info "... $(varToTitleCase ${FUNCNAME[0]})"
}

create_container() {
    print_info "$(varToTitleCase ${FUNCNAME[0]}) $CONTAINER_ID ..."

    if [ -n "$hwaddr" ]; then
        hwaddr=",hwaddr=$hwaddr"
    fi
    if [ "${IP_Config,,}" = "dhcp" ]; then
        net0="name=eth0,bridge=vmbr0$hwaddr,ip=dhcp"
    else
        net0="name=eth0,bridge=vmbr0$hwaddr,ip=${IP_Config}/24,gw=${GATEWAY}"
    fi

    local pct_create=$(cat <<pct_create
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
pct_create
    )
    echo $pct_create
    $pct_create
    
    print_info "... $CONTAINER_ID $(varToTitleCase ${FUNCNAME[0]})"
}

pct_start(){
    print_info "$(varToTitleCase ${FUNCNAME[0]}) $1 ..."
    pct start $1
    print_info "... $1 $(varToTitleCase ${FUNCNAME[0]})"
}

pct_restart(){
    print_info "$(varToTitleCase ${FUNCNAME[0]}) $1 ..."
    pct restart $1
    print_info "... $1 $(varToTitleCase ${FUNCNAME[0]})"
}

pct_status_running() {
    print_info "$(varToTitleCase ${FUNCNAME[0]}) $1 ..."
    while true; do
        if pct status $1 | grep -q "running"; then
            break
        fi
        sleep 1
    done
    print_info "... $1 $(varToTitleCase ${FUNCNAME[0]})"
}

wait_IP_ADDRESS() {
    local IP_Config=$1
    print_info "$(varToTitleCase ${FUNCNAME[0]}) $IP_Config $2 ..."
    if [ "${IP_Config,,}" = "dhcp" ]; then
        while true; do
            IP_Config=$(lxc-info -n $2 -i | awk '{print $2}')
            if [ -z "$IP_Config" ]; then
                echo "lxc-info -n $2 -i is empty, waiting 1s to retry ..."
                sleep 1
            else 
                break 
            fi
        done
    fi
    print_info "... $IP_Config $2 $(varToTitleCase ${FUNCNAME[0]})"
    echo $IP_Config
}

wait_ping() {
    set -e
    local IP_ADDRESS=$1
    local CONTAINER_ID=$2
    print_info "$(varToTitleCase ${FUNCNAME[0]}) $CONTAINER_ID ..."
    command="ping -c 1 $IP_ADDRESS"
    if [ "$CONTAINER_ID" != "" ] ; then
        command="pct exec $CONTAINER_ID -- $command"
    fi
    echo $command
    while ! $command; do
        print_warn "ping $IP_ADDRESS bad, witing 1s to retry ..."
        sleep 1
    done
    print_info "... $CONTAINER_ID $(varToTitleCase ${FUNCNAME[0]})"
}

container-getty_autologin() {
    local CONTAINER_ID=$1
    print_info "$(varToTitleCase ${FUNCNAME[0]}) $CONTAINER_ID ..."
    pct exec $CONTAINER_ID -- bash <<'pct_exec'
mkdir -p /etc/systemd/system/container-getty@1.service.d
echo '[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%I 115200,38400,9600 $TERM' > /etc/systemd/system/container-getty@1.service.d/override.conf
cat /etc/systemd/system/container-getty@1.service.d/override.conf
systemctl daemon-reload || true
systemctl enable container-getty@1.service || true
systemctl start container-getty@1.service || true
echo systemctl status container-getty@1.service
pct_exec
    print_info "... $CONTAINER_ID $(varToTitleCase ${FUNCNAME[0]})"
}

set_root_password() {
    if [ -n "$ROOT_PASSWORD" ]; then
        print_info "$(varToTitleCase ${FUNCNAME[0]}) $CONTAINER_ID ..."
        pct exec "$CONTAINER_ID" -- bash -c "echo 'root:${ROOT_PASSWORD}' | chpasswd" || print_warn "Failed to set root password"
        print_info "... $CONTAINER_ID $(varToTitleCase ${FUNCNAME[0]})"
    fi
}

configure_apt_cacher() {
    local APT_CACHER=$1
    local CONTAINER_ID=$2
    print_info "$(varToTitleCase ${FUNCNAME[0]}) $APT_CACHER $CONTAINER_ID ..."
    if [ -z "$APT_CACHER" ]; then
        print_warn "configure_apt_cacher not set, skipping apt-cacher-ng configuration"
        return
    fi
    local ostype=$(grep -w "ID" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    if [ $ostype = "alpine" ] ; then
        print_warn "configure_apt_cacher not work yet with $ostype"
        return
    fi
    # sanitize value: strip any http:// or https:// prefix if present
    APT_CACHER=${APT_CACHER#http://}
    APT_CACHER=${APT_CACHER#https://}
    SERVER="${APT_CACHER%%:*}" 
    PORT="${APT_CACHER##*:}"
    print_info "pinging $SERVER ..."
    if ! ping -c1 $SERVER &>/dev/null; then
        print_warn "APT_CACHER $SERVER not ping"
        input "Do you want to start container $CONTAINER_ID? (Y/n)" "REPLY" -n1
        if [[ ! "$REPLY" =~ ^[Yy]$ ]] && [[ -n "$REPLY" ]]; then
            print_info "$SERVER APT_CACHER $CONTAINER_ID not started"
            return 1
        fi
        time pct_start $CONTAINER_ID
        time pct_status_running $CONTAINER_ID
    fi
    time wait_ping $SERVER

    APT_CACHER="$SERVER:$PORT"
    pct exec $CONTAINER_ID -- bash <<pct_exec
mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/01proxy <<EOL
Acquire::http::Proxy "http://$APT_CACHER";
Acquire::https::Proxy "http://$APT_CACHER";
EOL
cat /etc/apt/apt.conf.d/01proxy
pct_exec
    print_info "... $APT_CACHER $CONTAINER_ID $(varToTitleCase ${FUNCNAME[0]})"
}

upDateGradeRemoving() {
    print_info "$(varToTitleCase ${FUNCNAME[0]}) $CONTAINER_ID ..."
    pct exec $CONTAINER_ID -- bash <<pct_exec
set -e
echo rm -f /etc/apt/apt.conf.d/01proxy
apt -y update
echo '...updated, upgrading...'
apt -y upgrade
echo '...upgraded, autoRemoving...'
apt -y autoremove
pct_exec
    print_info "... $CONTAINER_ID autoRemoving"
}

curl_github_latest_version(){
    #print_info "$(varToTitleCase ${FUNCNAME[0]}) $1 ..."
    curl -s https://api.github.com/repos/$1/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"+]+)".*/\1/'
    #print_info "... $1 $(varToTitleCase ${FUNCNAME[0]})"
}

reBoot() {
    echo "$(varToTitleCase ${FUNCNAME[0]}) $CONTAINER_ID..."
    pct reboot "$CONTAINER_ID"
    echo "... $CONTAINER_ID $(varToTitleCase ${FUNCNAME[0]})"
}

show_summary() {
    echo
    echo $(varToTitleCase ${FUNCNAME[0]})
    echo "========================================"
    cat /etc/pve/lxc/$CONTAINER_ID.conf
    echo "========================================"
    echo
}
