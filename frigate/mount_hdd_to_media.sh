#!/usr/bin/env bash
echo frigate
set -e
basename0sh=$(basename "$0" .sh)
echo "$basename0sh"
chmod +x "$0"
CONTAINER_ID=117
storage="hdd1"
gb=100
echo id=$CONTAINER_ID
echo storage=$storage
echo gb=$gb
pct exec "$CONTAINER_ID" -- cat /config/config.yaml | grep -A 1 "record:"
pct exec "$CONTAINER_ID" -- sed -i '/record:/,/^$/s/ enabled: true/  enabled: false/' /config/config.yaml
pct exec "$CONTAINER_ID" -- sh -c 'set -e
echo sed -i '/record:/,/^$/s/ enabled: true/  enabled: false/' /config/config.yaml
cat /config/config.yaml | grep -A 1 "record:"
rm -r /media/*
'
pct set $CONTAINER_ID -mp0 $storage:$gb,mp=/media
