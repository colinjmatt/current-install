#!/bin/bash
# BACKUP /home/user/    BEFORE REINSTALLING!!

# Set keyboard map & time sync
loadkeys uk
timedatectl set-ntp true

# Sort the mirrorlist so downloads are fast enough and from teh correct location
reflector --country 'United Kingdom' --latest 200 --age 24 --sort rate --save /etc/pacman.d/mirrorlist

# Create partitions, create and open encrypted volume and mount all partitions
parted -s /dev/nvme0n1 mklabel gpt
parted -s /dev/nvme0n1 mkpart ESP fat32 2048s 512MiB
parted -s /dev/nvme0n1 set 1 boot on
parted -s /dev/nvme0n1 mkpart primary ext4 512MiB 16896MiB
parted -s /dev/nvme0n1 mkpart primary ext4 16896MiB 100%

mkfs.vfat -F32 /dev/nvme0n1p1
mkswap /dev/nvme0n1p2
mkfs.ext4 /dev/nvme0n1p3

mount /dev/nvme0n1p3 /mnt
mkdir /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
swapon /dev/nvme0n1p2

# Install base system
pacstrap /mnt base base-devel amd-ucode linux linux-firmware systemd-resolvconf openssh wget nano git

# Generate fstab for filesystem mounts and add /tmp as ram drive
genfstab -pU /mnt >>/mnt/etc/fstab
echo "tmpfs	/tmp	tmpfs	defaults,noatime,mode=1777	0	0" >>/mnt/etc/fstab

# Copy mirrorlist to installed base system
cat /etc/pacman.d/mirrorlist >/mnt/etc/pacman.d/mirrorlist

# Chroot in
arch-chroot /mnt

# Unmount and reboot into installed system
umount -R /mnt
swapoff -a
reboot
