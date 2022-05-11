#!/bin/bash
virsh nodedev-reattach pci_0000_09_00_0
virsh nodedev-reattach pci_0000_09_00_1

systemctl start lightdm.service
systemctl start vncserver-x11-serviced

cpupower frequency-set -g powersave
