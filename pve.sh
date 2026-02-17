#!/usr/bin/env bash
#clear ; bash /home/sh/pve.sh
set -e
source "$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/function.sh"

toDo(){
    echo "toDo"
    echo https://community-scripts.github.io/ProxmoxVE
    echo
    echo https://tuxis.nl
    echo https://FL002291@pbs005.tuxis.nl:8007
    echo
    echo https://github.com/egmsystems/sh
    echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/egmsystems/sh/main/PVE-mods.sh)"'
    echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/egmsystems/sh/main/bootFromUSB.sh)"'
    echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/egmsystems/sh/main/PCI_Passthrough.sh)"'
    echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/egmsystems/sh/main/pve_createContainer-iVentoy.sh)"'
    echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/egmsystems/sh/main/pve_createContainer-qDevice.sh)"'
    echo
    echo Apt-Cacher-NG
    echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/apt-cacher-ng.sh)"'
    echo ls /usr/local/community-scripts/defaults/apt-cacher-ng.vars
    echo http://192.168.50.78:3142
    echo https://apt-cacher-ng.home1.egm.ns01.us/ 401 Authorization Required
    echo
    echo PVEScriptsLocal
    echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pve-scripts-local.sh)"'
    echo ls /usr/local/community-scripts/defaults/pve-scripts-local.vars
    echo http://192.168.50.80:3000 https://pvescriptslocal.home1.egm.ns01.us
    echo
    echo PVE Processor Microcode
    echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/microcode.sh)"'
    echo ls /usr/local/community-scripts/defaults/microcode.vars
    echo check: journalctl -k | grep -E "microcode" | head -n 1
    echo
    echo MQTT
    echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/mqtt.sh)"'
    echo ls /usr/local/community-scripts/defaults/mqtt.vars
    echo
    echo Wazuh
    echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/wazuh.sh)"'
    echo Username: root
    echo Show password: cat ~/wazuh.creds
    echo 'bash -c "$(curl -fsSL https://xyz)"'
    echo
    echo OpenWrt
    echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/openwrt.sh)"'
    echo ls /usr/local/community-scripts/defaults/openwrt.vars
    echo
    echo OneDev
    echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/onedev.sh)"'
    echo
}

configure_apt_cacher() {
    set -e
    echo $(varToTitleCase ${FUNCNAME[0]})
    local APT_CACHER=$1
    if [ -z "$APT_CACHER" ]; then
        print_warn "configure_apt_cacher not set, skipping apt-cacher-ng configuration"
        return
    fi
    ostype=$(grep -w "ID" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    if [ $ostype = "alpine" ] ; then
        print_warn "configure_apt_cacher not work yet with $ostype"
        return
    fi
    local CONTAINER_ID=$2
    # sanitize value: strip any http:// or https:// prefix if present
    APT_CACHER=${APT_CACHER#http://}
    APT_CACHER=${APT_CACHER#https://}
    APT_CACHER=${APT_CACHER#3142}
    print_info "pinging $APT_CACHER ..."
    if ! ping -c1 $APT_CACHER &>/dev/null; then
        print_warn "APT_CACHER $APT_CACHER not ping"
        input "Do you want to start container $CONTAINER_ID? (Y/n)" "REPLY" -n1
        echo "$REPLY"
        if [[ ! "$REPLY" =~ ^[Yy]$ ]] && [[ -n "$REPLY" ]]; then
            print_info "$APT_CACHER APT_CACHER $CONTAINER_ID not started"
            return 1
        fi
        time pct_start $CONTAINER_ID
        time wait_container $CONTAINER_ID
    fi
    time wait_ping $APT_CACHER

    APT_CACHER="$APT_CACHER:3142"
    mkdir -p /etc/apt/apt.conf.d
    echo "Acquire::http::Proxy \"http://$APT_CACHER\";" > /etc/apt/apt.conf.d/01proxy
    cat /etc/apt/apt.conf.d/01proxy
    echo toDo configure https to go through apt-cacher-ng via apt-transport-https wrappers if needed
    echo toDo mount /etc/apt/apt.conf.d/01proxy in all container
    print_info "...$APT_CACHER configure_apt_cacher"
}

upDateGradeRemoving() {
    set -e
    print_info $(varToTitleCase ${FUNCNAME[0]})
    apt -y update
    apt -y upgrade
    apt -y autoremove
    echo
}

main() {
    bashStart "0.0.1"
    configure_apt_cacher "192.168.50.78" 100
    time upDateGradeRemoving
    #toDo
}
time main