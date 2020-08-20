#!/bin/bash
# BACKUP /home/user/    BEFORE REINSTALLING!!

# Set time & keyboard map
timedatectl set-ntp true
loadkeys uk.map.gz

# Sort the mirrorlist so downloads are fast enough
grep --no-group-separator -A1 "United Kingdom" /etc/pacman.d/mirrorlist > /mirrorlist
cat /mirrorlist > /etc/pacman.d/mirrorlist

# Create partitions, create and open encrypted volume and mount all partitions
parted -s /dev/sda mklabel gpt
parted -s /dev/sda mkpart ESP fat32 2048s 512MiB
parted -s /dev/sda set 1 boot on
parted -s /dev/sda mkpart primary ext4 512MiB 16896MiB
parted -s /dev/sda mkpart primary ext4 16896MiB 100%

mkfs.vfat -F32 /dev/sda1
mkswap /dev/sda2
mkfs.ext4 /dev/sda3

mount /dev/sda3 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
swapon /dev/sda2

# Install base system
pacstrap /mnt base base-devel amd-ucode linux linux-firmware systemd-resolvconf openssh wget nano git

# Generate fstab for filesystem mounts and add /tmp as ram drive
genfstab -pU /mnt >>/mnt/etc/fstab
echo "tmpfs	/tmp	tmpfs	defaults,noatime,mode=1777	0	0" >>/mnt/etc/fstab

# Copy mirrorlist to installed base system
cat /mirrorlist >/mnt/etc/pacman.d/mirrorlist

# Chroot in
arch-chroot /mnt

# Unmount and reboot into installed system
umount -R /mnt
swapoff -a
reboot
