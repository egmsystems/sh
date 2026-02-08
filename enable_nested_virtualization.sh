#!/usr/bin/env bash
cpu_vendor=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
if [ "$cpu_vendor" == "GenuineIntel" ]; then
    if ! grep -q "options kvm-intel nested=Y" /etc/modprobe.d/kvm-intel.conf 2>/dev/null; then
        echo Enabling nested virtualization for Intel CPUs...
        echo "options kvm-intel nested=Y" >> /etc/modprobe.d/kvm-intel.conf
        modprobe -r kvm_intel
        modprobe kvm_intel
    else
        echo Nested virtualization for Intel CPUs is already enabled.
    fi
    cat /sys/module/kvm_intel/parameters/nested
elif [ "$cpu_vendor" == "AuthenticAMD" ]; then
    if ! grep -q "options kvm-amd nested=1" /etc/modprobe.d/kvm-amd.conf 2>/dev/null; then
        echo Enabling nested virtualization for AMD CPUs...
        echo "options kvm-amd nested=1" >> /etc/modprobe.d/kvm-amd.conf
        modprobe -r kvm_amd
        modprobe kvm_amd
    else
        echo Nested virtualization for AMD CPUs is already enabled.
    fi
    cat /sys/module/kvm_amd/parameters/nested
else
    echo "Unsupported CPU type ($cpu_vendor). This script only supports Intel and AMD CPUs."
fi
