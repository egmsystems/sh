#!/usr/bin/env bash
echo frigate
echo version 0.0.3
set -e
basename0sh=$(basename "$0" .sh)
echo "$basename0sh"
chmod +x "$0"
CONTAINER_ID=114

set_mp() {
    storage="hdd1"
    gb=100
    read -p "storage [$storage]: " input_id
    storage="${input_id:-$storage}"
    read -p "gb [$gb]: " input_id
    gb="${input_id:-$gb}"
    pct exec "$CONTAINER_ID" -- sh -c "set -e
    echo sed -i '/^record:/,/^$/s/ enabled: True/  enabled: false/' /config/config.yaml
    cd /media/
    rm -rf frigate
    "
    pct set $CONTAINER_ID -mp0 $storage:$gb,mp=/media
    pct exec "$CONTAINER_ID" -- sh -c "set -e
    cd /media/
    mkdir -p frigate/clips
    mkdir -p frigate/exports
    mkdir -p frigate/recordings
    "
}
sed_config() {
    pct exec "$CONTAINER_ID" -- cat /config/config.yaml | grep -A 1 "record:"
    pct exec "$CONTAINER_ID" -- sed -i '/^record:/,/^$/s/ enabled: True/  enabled: false/' /config/config.yaml
}
main() {
    read -p "CONTAINER_ID [$CONTAINER_ID]: " input_id
    CONTAINER_ID="${input_id:-$CONTAINER_ID}"
    set_mp
    #sed_config
}
main