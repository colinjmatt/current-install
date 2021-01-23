#!/bin/sh
if [ ! -f ~/attach ]; then
  sudo virsh attach-device win10-gaming /etc/libvirt/devices/logi_mouse.xml || { echo 'Failed to attach device(s)' ; exit 1; }
  sudo virsh attach-device win10-gaming /etc/libvirt/devices/logi_keyb.xml || { echo 'Failed to attach device(s)' ; exit 1; }
  touch ~/attach
else
  sudo virsh detach-device win10-gaming /etc/libvirt/devices/logi_mouse.xml
  sudo virsh detach-device win10-gaming /etc/libvirt/devices/logi_keyb.xml
  rm ~/attach
fi
