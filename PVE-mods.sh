#!/bin/bash

apt-get -y install lm-sensors
# lm-sensors must be configured, run below to configure your sensors, apply temperature offsets. Refer to lm-sensors manual for more information.
sensors-detect 

#wget https://raw.githubusercontent.com/Meliox/PVE-mods/refs/heads/main/pve-mod-gui-sensors.sh
#bash pve-mod-gui-sensors.sh install
TEMP_SCRIPT=$(mktemp)
curl -fsSL https://raw.githubusercontent.com/egmsystems/PVE-mods/refs/heads/main/pve-mod-gui-sensors.sh -o "$TEMP_SCRIPT"
bash "$TEMP_SCRIPT" install
rm -f "$TEMP_SCRIPT"
# Then clear the browser cache to ensure all changes are visualized.
