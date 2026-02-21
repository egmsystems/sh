# Proxmox VE Helper Scripts

This repository contains a collection of shell scripts to assist with the configuration and management of Proxmox VE (PVE) systems.

## Files

### `PCI_Passthrough.sh`
A comprehensive script to configure PCI Passthrough on Proxmox VE.
- **Features**:
  - Detects CPU vendor (Intel/AMD) and enables IOMMU support.
  - Verifies IOMMU interrupt remapping.
  - Blacklists common GPU drivers (NVIDIA, AMD, Intel) to prepare for passthrough.
  - Adds necessary modules (`vfio`, `vfio_pci`, etc.) to `/etc/modules`.
  - Updates GRUB and initramfs configurations.
  - Helper functions to list, create, and configure VMs for passthrough.

### `pve.sh`
A utility script containing shortcuts and commands for deploying various services and community scripts on PVE.
- Includes commands for:
  - Apt-Cacher-NG
  - PVE Processor Microcode updates
  - MQTT, Wazuh, OpenWrt, OneDev

### `PVE-mods.sh`
Script to install and configure hardware monitoring tools.
- Installs `lm-sensors`.
- Runs `sensors-detect`.
- Installs `pve-mod-gui-sensors` to display temperatures in the Proxmox web interface.

### `bootFromUSB.sh`
Contains commands and notes related to storage configuration, likely for setting up USB boot environments or testing disk I/O with `dd`.

## Usage
**⚠️ Warning**: These scripts modify system configurations (GRUB, modules, etc.). Always review the code before running it on your system.

```bash
# Make scripts executable
chmod +x script_name.sh

# Run a script
./script_name.sh
```
