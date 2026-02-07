#!/usr/bin/env bash
set -e
echo PCI_Passthrough
echo v0.1.0
echo https://pve.proxmox.com/wiki/PCI_Passthrough
echo
echo Verifying:

echo CPU...
cpu_vendor=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
iommu_param=""
if [ "$cpu_vendor" == "GenuineIntel" ]; then
    echo "$cpu_vendor CPU detected."
    if dmesg | grep -q "Intel(R) Virtualization Technology for Directed I/O"; then
        iommu_param="intel_iommu=on"
    fi
elif [ "$cpu_vendor" == "AuthenticAMD" ]; then
    echo "$cpu_vendor CPU detected."
    if dmesg | grep -q "AMD-Vi: AMD IOMMU initialized"; then
        iommu_param="amd_iommu=on"
    fi
else
    echo "Unknown CPU vendor: $cpu_vendor"
    exit 1
fi
if [ "$cpu_vendor" == "" ]; then
    echo "No virtualization technology activadated, check your BIOS (VT-x, AMD-V)"
    dmesg | grep -e DMAR
    exit 1
fi
iommu_param="$iommu_param iommu=pt"
echo "Configuring GRUB with $iommu_param..."
if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub; then
    if ! grep -q "$iommu_param" /etc/default/grub; then
        sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*/& $iommu_param/" /etc/default/grub
        echo "Added $iommu_param to GRUB_CMDLINE_LINUX_DEFAULT"
        update-grub
        read -t 5 -p "Do you want to reboot now? [Y/n] " -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            reboot
        fi
    else
        echo "$iommu_param is already set in GRUB."
    fi
else
    echo "Error: GRUB_CMDLINE_LINUX_DEFAULT not found in /etc/default/grub"
    exit 1
fi
echo IOMMU...
tmp=$(dmesg | grep -e IOMMU)
if [ "$tmp" = "" ]; then
    echo It is not OK
    dmesg | grep -e DMAR
    echo "https://pve.proxmox.com/wiki/PCI_Passthrough#Verify_IOMMU_is_enabled"
    exit 1
fi
echo remapping...
tmp=$(dmesg | grep -e 'remapping')
if [ "$tmp" = "" ]; then
    echo "your system doesn't support interrupt remapping"
    echo "https://pve.proxmox.com/wiki/PCI_Passthrough#Verify_IOMMU_interrupt_remapping_is_enabled"
    tmp="/etc/modprobe.d/iommu_unsafe_interrupts.conf"
    tmp2="options vfio_iommu_type1 allow_unsafe_interrupts=1"
    if [ !-f $tmp ]; then
        echo you can allow unsafe interrupts with:
        echo "$tmp2 > $tmp"
        exit 2
    else
        tmp=$(cat $tmp)
        if [ "$tmp" != "$tmp2" ]; then
            echo "https://pve.proxmox.com/wiki/PCI_Passthrough#Verify_IOMMU_interrupt_remapping_is_enabled"
            echo "$tmp2 > $tmp"
            exit 3
        fi
    fi
fi

gpu=$(lspci | grep -E "VGA|3D|Display")
echo "GPU vendor: $gpu"
echo Blacklisting GPU drivers...
if echo "$gpu" | grep -qi "Intel"; then
    echo "blacklist i915" > /etc/modprobe.d/blacklist.conf
elif echo "$gpu" | grep -qi "AMD"; then
    echo "blacklist amdgpu" > /etc/modprobe.d/blacklist.conf
    echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
elif echo "$gpu" | grep -qi "NVIDIA"; then
    echo "blacklist nouveau" > /etc/modprobe.d/blacklist.conf 
    echo "blacklist nvidia*" >> /etc/modprobe.d/blacklist.conf 
else
    echo "Unknown GPU vendor"
    exit 4 
fi

echo vf io to /etc/modules...
modules_changed=0
if ! grep -q "vfio" /etc/modules; then
    echo adding vfio to /etc/modules
    echo "vfio" >> /etc/modules
    modules_changed=1
fi
if ! grep -q "vfio_iommu_type1" /etc/modules; then
    echo adding vfio_iommu_type1 to /etc/modules
    echo "vfio_iommu_type1" >> /etc/modules
    modules_changed=1
fi
if ! grep -q "vfio_pci" /etc/modules; then
    echo adding vfio_pci to /etc/modules
    echo "vfio_pci" >> /etc/modules
    modules_changed=1
fi
if [ "$modules_changed" -eq 1 ]; then
    update-initramfs -u -k all
    read -t 5 -p "Do you want to reboot now? [Y/n] " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        reboot
    fi
fi
if ! lsmod | grep vfio ; then
    echo "vfio not loaded or you need to reboot"
    exit 5
fi

function create_vm() {
    local vmid=$1
    local vm_name=$2
    echo "No VMs found."
    echo "Creating a VM with ID $vmid..."
    qm create $vmid --name $vm_name --machine q35 --bios ovmf --efidisk0 local:0,efitype=4m,pre-enrolled-keys=0
    selected_vmid=$vmid
}

function list_vms() {
    vm_ids=()
    vm_names=()
    i=1
    while read -r line; do
        vm_id=$(echo "$line" | awk '{print $1}')
        vm_name=$(echo "$line" | awk '{print $2}')
        vm_ids+=("$vm_id")
        vm_names+=("$vm_name")
        echo "[$i] $vm_id - $vm_name"
        i=$((i+1))
    done <<< "$vm_list"
}

function select_vm() {
    default_index=1
    echo
    read -p "Select a VM [Default: $default_index (${vm_ids[0]})]: " selection
    if [ -z "$selection" ]; then
        selection=$default_index
    fi

    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#vm_ids[@]}" ]; then
        selected_index=$((selection-1))
        selected_vmid=${vm_ids[$selected_index]}
        echo "Selected VM: $selected_vmid (${vm_names[$selected_index]})"
    else
        echo "Invalid selection."
        exit 7
    fi
    echo "qm set $selected_vmid --cpu host,hidden=1 --machine q35 --bios ovmf --efidisk0 local:0,efitype=4m,pre-enrolled-keys=0"
}

function set_gpu_passthrough() {
    local vmid=$1
    local gpu_info="$2"
    echo GPU devices:
    gpu_ids=$(echo "$gpu_info" | awk '{print $1}')
    #echo "" > /etc/modprobe.d/vfio.conf
    local idx=0
    for id in $gpu_ids; do
        echo "Found GPU at: $id"
        lspci -k -s $id
        #echo "optons vfio-pci ids=$id disable_vga=1" >> /etc/modprobe.d/vfio.conf
        echo "qm set $vmid --hostpci$idx $id,pcie=1,x-vga=1"
        idx=$((idx+1))
    done
}

echo "Fetching VM list..."
vm_list=$(qm list | tail -n +2)
if [ -z "$vm_list" ]; then
    vm_id=$(pvesh get /cluster/nextid)
    create_vm $vm_id "w1"
else
    list_vms
    select_vm
fi

set_gpu_passthrough $selected_vmid "$gpu"