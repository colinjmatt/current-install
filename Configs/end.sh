#!/bin/bash
virsh nodedev-reattach pci_0000_09_00_0
virsh nodedev-reattach pci_0000_09_00_1

systemctl start \
    lightdm.service \
    vncserver-x11-serviced.service \
    nvidia-persistenced.service

cpupower frequency-set -g powersave