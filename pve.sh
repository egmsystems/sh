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
echo https://community-scripts.github.io/ProxmoxVE/scripts?id=apt-cacher-ng
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/apt-cacher-ng.sh)"
echo ls /usr/local/community-scripts/defaults/apt-cacher-ng.vars
echo http://192.168.50.78:3142
echo https://apt-cacher-ng.home1.egm.ns01.us/ 401 Authorization Required
echo
echo PVEScriptsLocal
echo https://community-scripts.github.io/ProxmoxVE/scripts?id=pve-scripts-local
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pve-scripts-local.sh)"
echo ls /usr/local/community-scripts/defaults/pve-scripts-local.vars
echo http://192.168.50.80:3000 https://pvescriptslocal.home1.egm.ns01.us
echo
echo PVE Processor Microcode
echo https://community-scripts.github.io/ProxmoxVE/scripts?id=microcode
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/microcode.sh)"
echo ls /usr/local/community-scripts/defaults/microcode.vars
echo check: journalctl -k | grep -E "microcode" | head -n 1
echo
echo MQTT
echo https://community-scripts.github.io/ProxmoxVE/scripts?id=mqtt
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/mqtt.sh)"
echo ls /usr/local/community-scripts/defaults/mqtt.vars
echo
echo Wazuh
echo https://community-scripts.github.io/ProxmoxVE/scripts?id=wazuh
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/wazuh.sh)"
echo Show password: cat ~/wazuh.creds
echo wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.14.2-1_amd64.deb && WAZUH_MANAGER='192.168.50.223' dpkg -i ./wazuh-agent_4.14.2-1_amd64.deb
echo cat /var/ossec/etc/ossec.conf
echo reemplaza WAZUH_MANAGER por la IP del manager
echo    <address>WAZUH_MANAGER</address>
echo nano /var/ossec/etc/ossec.conf
echo
echo OpenWrt
echo https://community-scripts.github.io/ProxmoxVE/scripts?id=openwrt
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/openwrt.sh)"
echo ls /usr/local/community-scripts/defaults/openwrt.vars
echo
echo PVE LXC Execute Command
echo https://community-scripts.github.io/ProxmoxVE/scripts?id=lxc-execute
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/execute.sh)"
echo
echo iVentoy
echo bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/ct/iventoy.sh)"
echo
echo OneDev
echo https://community-scripts.github.io/ProxmoxVE/scripts?id=onedev
echo bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/onedev.sh)"
echo
echo Microsoft Activation Scripts (MAS)
echo https://massgrave.dev
