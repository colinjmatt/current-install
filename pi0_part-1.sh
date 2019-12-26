#!/bin/bash
drive="sdd"
essid="Wi-Fi"
key="abcd1234"

parted -s /dev/sdd mklabel msdos
parted -s /dev/sdd mkpart primary fat32 2048s 100MiB
parted -s /dev/sdd set 1 boot on
parted -s /dev/sdd mkpart primary ext4 100MiB 100%

mkfs.vfat /dev/"$drive"1
mkfs.ext4 /dev/"$drive"2

mkdir -p /mnt/PI/{boot,root}
mkdir /mnt/PI/boot
mount /dev/"$drive"1 /mnt/PI/boot
mount /dev/"$drive"2 /mnt/PI/root

wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-latest.tar.gz # (RPi1 and 0)
#wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz # (RPi2 and 3)
#wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-3-latest.tar.gz # (ARMv8 x64 for pi 3)

bsdtar -xpf ArchLinuxARM*latest.tar.gz -C /mnt/PI/root
sync
mv /mnt/PI/root/boot/* /mnt/PI/boot/

cat ./PiConfigs/wlan0 >/mnt/PI/root/etc/netctl/wlan0
sed -i -e "\
  s/\$essid/""$essid""/g; \
  s/\$key/""$key""/g" \
/mnt/PI/root/etc/netctl/wlan0

sync
umount -R /mnt/PI/
rm -rf /mnt/PI
