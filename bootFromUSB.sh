#!/usr/bin/env bash
#chmod +x bootFromUSB.sh
set -e
source "$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/function.sh"

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

mountDirectoryToTmp() {
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

test() {
    storageSpeedTest ""
    storageSpeedTest "$hdd_directory/tmp"
    storageSpeedTest "$ssd_directory/tmp"
}

verifySwap() {
    echo $(varToTitleCase ${FUNCNAME[0]})
    swapon --show
    free -h
    echo
}

createSwapZvol() {
    echo $(varToTitleCase ${FUNCNAME[0]})
    echo
    echo $1 $2
    zfs create -V ${1}G \
        -b 8K \
        -o compression=zle \
        -o logbias=throughput \
        -o sync=always \
        -o primarycache=metadata \
        ${2#/}/swap
    mkswap /dev/zvol$2/swap --label swapFile$(hostname)
    swapon /dev/zvol$2/swap
    verifySwap
    cat /etc/fstab
    echo "/dev/zvol$2/swap none swap defaults 0 0" >> /etc/fstab
    nano /etc/fstab
    mount -a
    swapoff -a
    swapon -a
    verifySwap
    echo
}

createSwapFile() {
    echo $(varToTitleCase ${FUNCNAME[0]})
    echo
    if fallocate -l ${1}G $2/swapfile; then
        echo fallocate -l ${1}G $2/swapfile
    else
        dd if=/dev/zero of=$2/swapfile bs=1M count=$(($1 * 1024)) status=progress
    fi
    ls -all $2/swapfile
    chmod 600 $2/swapfile
    mkswap $2/swapfile --label swapFile$(hostname)
    swapon $2/swapfile
    verifySwap
    cat /etc/fstab
    echo "$2/swapfile none swap sw 0 0" >> /etc/fstab
    nano /etc/fstab
    swapoff $2/swapfile
    swapon -a
    swapon --show
    echo
}

setSwap() {
    echo $(varToTitleCase ${FUNCNAME[0]})
    local setSwap=${1:-100}
    sysctl vm.swappiness
    sysctl vm.swappiness=$setSwap
    if [ $setSwap -eq 100 ]; then
        rm /etc/sysctl.d/99-swappiness.conf
    else
        echo vm.swappiness=$setSwap > /etc/sysctl.d/99-swappiness.conf
    fi
    echo    
}

querySwap() {
    echo $(varToTitleCase ${FUNCNAME[0]})
    RAM=$(free -m | awk '/Mem/{print $2}')
    echo RAM=$RAM
    fs=$(df -Th "$ssd_directory" | awk 'NR==2 {print $2}')
    if [ "$fs" == "btrfs" ]; then
        echo "btrfs: requiere configuración especial (NOCOW)."
    elif [ "$fs" == "zfs" ]; then
        createSwapZvol $RAM $ssd_directory
    elif [[ "$fs" == "ext4" || "$fs" == "xfs" ]]; then
        createSwapFile $RAM $ssd_directory
    else
        echo "fs=$fs"
        exit 1
    fi
    echo
}

main() {
    echo version 0.0.1
    echo
    mode=1777
    ssd_directory="/ssd1"
    echo "toDo logs & cache"
    mkdir -pv -m $mode $ssd_directory/{tmp,var/tmp,var/cache}
    echo chmod $mode $ssd_directory/{tmp,var/tmp,var/cache}
    hdd_directory="/hdd1"
    mkdir -pv -m $mode $hdd_directory/tmp
    echo chmod $mode $hdd_directory/tmp

    installScript
    pvesm_add_dir_local
    echo $(varToTitleCase "storageSpeedTest")
    #test
    querySwap
    #setSwap 50
    echo $(varToTitleCase "mountDirectoryToTmp")
    mountDirectoryToTmp $ssd_directory $mode "tmp"
    mountDirectoryToTmp $ssd_directory $mode "var/tmp"
    mountDirectoryToTmp $ssd_directory $mode "var/cache"
}

bashStart
main