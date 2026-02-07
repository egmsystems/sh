#!/bin/bash

apt-get -y install lm-sensors
# lm-sensors must be configured, run below to configure your sensors, apply temperature offsets. Refer to lm-sensors manual for more information.
sensors-detect 

echo 💡   WARNING: This script will run an external installer from a third-party source (https://wazuh.com/).
  💡   The following code is NOT maintained or audited by our repository.
  💡   If you have any doubts or concerns, please review the installer code before proceeding:
         🌐   →  https://packages.wazuh.com/4.14/wazuh-install.sh
read -p "Do you want to continue? [Y/n] " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    wget https://raw.githubusercontent.com/Meliox/PVE-mods/refs/heads/main/pve-mod-gui-sensors.sh
    bash pve-mod-gui-sensors.sh install
    echo Then clear the browser cache to ensure all changes are visualized.
fi
