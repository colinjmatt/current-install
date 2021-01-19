#!/bin/bash
smbus=$(i2cdetect -l | grep smbus | awk -F ' ' '{print $1}')
ledcontroller=$(grep -rnw /sys/class/hidraw/hidraw*/device/uevent -e 'AsusTek Computer Inc. AURA LED Controller' | awk -F ':' '{print $1}' | awk -F '/' '{print $5}')
display=$(grep -rnw /sys/class/hidraw/hidraw*/device/uevent -e 'AsusTek Computer Inc. AURA LED Controller' | awk -F ':' '{print $1}' | awk -F '/' '{print $5}')
ROG Gaming Display Aura Device ROG Gaming Display Aura Device

chmod 777 /dev/"$ledcontroller" /dev/"$display"

for i2c in $smbus; do
  chmod 777 /dev/"$i2c";
done

modprobe i2c-dev
modprobe i2c-i801
modprobe i2c-nct6775
