#!/bin/bash
# Reattach the GPU and audio devices to the host
virsh nodedev-reattach pci_0000_09_00_1
virsh nodedev-reattach pci_0000_09_00_0

# Reload NVIDIA kernel modules
modprobe nvidia
modprobe nvidia_uvm
modprobe nvidia_modeset
modprobe nvidia_drm

# Unbind the VT console (Virtual Terminals)
echo 1 > /sys/class/vtconsole/vtcon0/bind

# Restart the persistence daemon and display manager
systemctl start nvidia-persistenced.service
systemctl start sddm.service

# Return CPU governor to powersave
cpupower frequency-set -g powersave
