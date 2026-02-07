#!/usr/bin/env bash
echo Boot from USB
echo
echo On install part:
echo root=100%
echo swuap=0
echo lvm=0
echo
echo /tmp
echo Escritura
echo dd if=/dev/zero of=/tmp/testfile bs=1M count=1024 conv=fdatasync
echo Lectura
echo dd if=/tmp/testfile of=/dev/null bs=1M count=1024
echo Escritura
echo dd if=/dev/zero of=/mnt/pve/sdd1/testfile bs=1M count=1024 conv=fdatasync
echo Lectura
echo dd if=/mnt/pve/sdd1/testfile of=/dev/null bs=1M count=1024
echo mkdir -p /mnt/sdd1/tmp
echo chmod 1777 /mnt/pve/sdd1/tmp
echo mv /tmp/* /mnt/sdd1/tmp/
echo rm -rf /tmp
echo mount --bind /mnt/pve/sdd1/tmp /tmp
echo cat /etc/fstab
echo echo "/mnt/pve/sdd1/tmp /tmp tmpfs defaults,noatime,nosuid,nodev,mode=1777 0 0" >> /etc/fstab
echo mount -a
