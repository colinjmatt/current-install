#!/bin/bash

parted -s /dev/sdd mklabel msdos
parted -s /dev/sdd mkpart primary fat32 2048s 100MiB
parted -s /dev/sdd set 1 boot on
parted -s /dev/sdd mkpart primary ext4 100MiB 100%

mkfs.vfat /dev/sdd1
mkfs.ext4 /dev/sdd2

mkdir -p /mnt/PI
cd /mnt/PI || return
mkdir boot
mount /dev/sdd1 ./boot

mkdir root
mount /dev/sdd2 ./root

wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-latest.tar.gz # (RPi1 and 0)
#wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz # (RPi2 and 3)
#wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-3-latest.tar.gz # (ARMv8 x64 for pi 3)

bsdtar -xpf ArchLinuxARM*latest.tar.gz -C ./root/
sync
mv root/boot/* ./boot/

cat ./PiConfigs/wlan0 >./etc/netctl/
Description='Wi-Fi'
Interface=wlan0
Connection=wireless
Security=wpa
ESSID=Tinkerbell
IP=static
Address='192.168.0.110/24'
Gateway='192.168.0.1'
DNS=('192.168.0.81' '1.1.1.1' '1.0.0.1')
Key=


sync
umount ./boot ./root
