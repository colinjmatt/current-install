#!/bin/bash
cpupower frequency-set -g performance

systemctl stop \
    vncserver-x11-serviced.service \
    lightdm.service \
    nvidia-persistenced.service

modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r nvidia_uvm
modprobe -r nvidia

virsh nodedev-detach pci_0000_09_00_0
virsh nodedev-detach pci_0000_09_00_1