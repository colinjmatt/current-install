#!/bin/bash
# Maximize CPU performance
cpupower frequency-set -g performance

# Stop display manager and persistence daemon
systemctl stop sddm.service
systemctl stop nvidia-persistenced.service

# Loop until SDDM is definitively inactive
while systemctl is-active --quiet sddm.service; do
    sleep 1
    echo "Waiting for SDDM to stop..."
done

# Unbind the VT console (Virtual Terminals)
echo 0 > /sys/class/vtconsole/vtcon0/bind

# Unload NVIDIA kernel modules safely
modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r nvidia_uvm
modprobe -r nvidia

# Detach the GPU from the host
virsh nodedev-detach pci_0000_09_00_0
virsh nodedev-detach pci_0000_09_00_1

# Wait a moment to ensure the GPU is fully detached before starting the VM
sleep 2