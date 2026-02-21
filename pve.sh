#!/usr/bin/env bash
echo PVE
echo https://community-scripts.github.io/ProxmoxVE
echo
echo https://tuxis.nl
echo https://FL002291@pbs005.tuxis.nl:8007
echo
echo https://github.com/egmsystems/sh
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/egmsystems/sh/main/PVE-mods.sh)"
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/egmsystems/sh/main/PCI_Passthrough.sh)"
echo
echo Apt-Cacher-NG
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/apt-cacher-ng.sh)"
echo ls /usr/local/community-scripts/defaults/apt-cacher-ng.vars
echo http://192.168.50.78:3142
echo https://apt-cacher-ng.home1.egm.ns01.us/ 401 Authorization Required
echo
echo PVEScriptsLocal
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pve-scripts-local.sh)"
echo ls /usr/local/community-scripts/defaults/pve-scripts-local.vars
echo http://192.168.50.80:3000 https://pvescriptslocal.home1.egm.ns01.us
echo
echo PVE Processor Microcode
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/microcode.sh)"
echo ls /usr/local/community-scripts/defaults/microcode.vars
echo check: journalctl -k | grep -E "microcode" | head -n 1
echo
echo MQTT
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/mqtt.sh)"
echo ls /usr/local/community-scripts/defaults/mqtt.vars
echo
echo Wazuh
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/wazuh.sh)"
echo Username: root
echo Show password: cat ~/wazuh.creds
echo
echo OpenWrt
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/openwrt.sh)"
echo ls /usr/local/community-scripts/defaults/openwrt.vars
echo
echo OneDev
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/onedev.sh)"
echo
echo Microsoft Activation Scripts (MAS)
echo https://massgrave.dev
