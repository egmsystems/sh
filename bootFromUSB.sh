#!/usr/bin/env bash
function bashStart() {
    set -e
    chmod +x $0
    echo $(camelCaseToTitleCase $(basename "$0" .sh))
}

function varToCamelCase() {
    toUpperCaseFirstLetter=$(echo $1 | sed 's/\([a-z]\)_\([a-z]\)/\1\U\2/g')
    echo ${toUpperCaseFirstLetter^}
}

function camelCaseToTitleCase() {
    echo $1 | sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g'
}

function varToTitleCase() {
    echo $(camelCaseToTitleCase $(varToCamelCase $1))
}

installScript() {
    echo $(varToTitleCase ${FUNCNAME[0]})
    echo Disk Partitions
    echo root=100%
    echo lvm=0
    echo swap=0
    echo
}

pvesm_add_dir_local() {
    echo $(varToTitleCase ${FUNCNAME[0]})
    echo pvesm add dir local-ssd1 --path $ssd_directory/directory --create-base-path --create-subdirs
    echo
}

storageSpeedTest() {
    local params="bs=1M count=1024"
    local testfile="testfile"
    echo dd if=/dev/zero of=$1/$testfile $params conv=fdatasync #Writing
    echo dd if=$1/$testfile of=/dev/null $params # Reading
    echo rm $1/$testfile
    echo
}

mountDiectoryToTmp() {
    local tmp_old="/$3"
    local tmp_new="$1/$3"
    echo "cp -rf $tmp_old/* $tmp_new"
    echo rm -rf $tmp_old/*
    echo mount --bind $tmp_new $tmp_old
    echo cat /etc/fstab
    echo "echo '$tmp_new $tmp_old tmpfs defaults,noatime,nosuid,nodev,mode=$2 0 0' >> /etc/fstab"
    echo nano /etc/fstab
    echo mount -a
    echo systemctl daemon-reload
    echo
}

main() {
    echo version 0.0.1
    echo
    mode=1777
    hdd_directory="/hdd1"
    ssd_directory="/ssd1"
    mkdir -pv -m $mode $hdd_directory/tmp #{swap,logs,cache}
    mkdir -pv -m $mode $ssd_directory/{tmp,var/tmp,var/cache}
    chmod 1777 /var/tmp

    installScript
    pvesm_add_dir_local
    echo $(varToTitleCase "storageSpeedTest")
    storageSpeedTest ""
    storageSpeedTest "$hdd_directory/tmp"
    storageSpeedTest "$ssd_directory/tmp"
    echo $(varToTitleCase "mountDiectoryToTmp")
    mountDiectoryToTmp $ssd_directory $mode "tmp"
    mountDiectoryToTmp $ssd_directory $mode "var/tmp"
    mountDiectoryToTmp $ssd_directory $mode "var/cache"
}

bashStart
main