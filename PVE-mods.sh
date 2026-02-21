#!/bin/bash
#chmod +x PVE-mods.sh
set -e

apt-get -y install lm-sensors
# lm-sensors must be configured, run below to configure your sensors, apply temperature offsets. Refer to lm-sensors manual for more information.
sensors-detect 

#wget https://raw.githubusercontent.com/Meliox/PVE-mods/refs/heads/main/pve-mod-gui-sensors.sh
wget https://raw.githubusercontent.com/egmsystems/PVE-mods/refs/heads/main/pve-mod-gui-sensors.sh
bash pve-mod-gui-sensors.sh install
rm -f pve-mod-gui-sensors.sh
# Then clear the browser cache to ensure all changes are visualized.
