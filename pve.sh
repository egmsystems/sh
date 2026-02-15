#!/usr/bin/env bash
#set -e
echo $(echo $(basename "$0" .sh) | sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g')
echo version 0.0.1
echo
chmod +x $0
echo https://community-scripts.github.io/ProxmoxVE
echo
echo https://tuxis.nl
echo https://FL002291@pbs005.tuxis.nl:8007
echo
echo https://github.com/egmsystems/sh
#bash -c "$(curl -fsSL https://raw.githubusercontent.com/egmsystems/sh/main/PVE-mods.sh)"
#bash -c "$(curl -fsSL https://raw.githubusercontent.com/egmsystems/sh/main/PCI_Passthrough.sh)"
#bash -c "$(curl -fsSL https://raw.githubusercontent.com/egmsystems/sh/main/pve_createContainer-iVentoy.sh)"
#bash -c "$(curl -fsSL https://raw.githubusercontent.com/egmsystems/sh/main/pve_createContainer-qDevice.sh)"
echo
echo Apt-Cacher-NG
#bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/apt-cacher-ng.sh)"
echo ls /usr/local/community-scripts/defaults/apt-cacher-ng.vars
echo http://192.168.50.78:3142
echo https://apt-cacher-ng.home1.egm.ns01.us/ 401 Authorization Required
echo
echo PVEScriptsLocal
#bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pve-scripts-local.sh)"
echo ls /usr/local/community-scripts/defaults/pve-scripts-local.vars
echo http://192.168.50.80:3000 https://pvescriptslocal.home1.egm.ns01.us
echo
echo PVE Processor Microcode
#bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/microcode.sh)"
echo ls /usr/local/community-scripts/defaults/microcode.vars
echo check: journalctl -k | grep -E "microcode" | head -n 1
echo
echo MQTT
#bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/mqtt.sh)"
echo ls /usr/local/community-scripts/defaults/mqtt.vars
echo
echo Wazuh
#bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/wazuh.sh)"
echo Username: root
echo Show password: cat ~/wazuh.creds
echo
echo OpenWrt
#bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/openwrt.sh)"
echo ls /usr/local/community-scripts/defaults/openwrt.vars
echo
echo OneDev
#bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/onedev.sh)"
echo