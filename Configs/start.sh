#!/bin/bash
cpupower frequency-set -g performance

systemctl stop vncserver-x11-serviced
systemctl stop lightdm.service

virsh nodedev-detach pci_0000_09_00_0
virsh nodedev-detach pci_0000_09_00_1
