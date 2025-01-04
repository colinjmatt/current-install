#!/bin/bash
virsh nodedev-reattach pci_0000_09_00_0
virsh nodedev-reattach pci_0000_09_00_1

modprobe nvidia_drm
modprobe nvidia_modeset
modprobe nvidia_uvm
modprobe nvidia

systemctl start \
    lightdm.service \
    vncserver-x11-serviced.service \
    nvidia-persistenced.service

cpupower frequency-set -g powersave