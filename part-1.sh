#!/bin/bash
# BACKUP /home/user/    BEFORE REINSTALLING!!
# BACKUP /etc/libvirt/  BEFORE REINSTALLING!!

# Set time & keyboard map
timedatectl set-ntp true
loadkeys uk.map.gz

# Sort the mirrorlist so downloads are fast enough
grep --no-group-separator -A1 "United Kingdom" /etc/pacman.d/mirrorlist > /mirrorlist
cat /mirrorlist > /etc/pacman.d/mirrorlist

# Create partitions, create and open encrypted volume and mount all partitions
parted -s /dev/nvme0n1 mklabel gpt
parted -s /dev/nvme0n1 mkpart ESP fat32 2048s 512MiB
parted -s /dev/nvme0n1 set 1 boot on
parted -s /dev/nvme0n1 mkpart primary ext4 512MiB 100%
mkfs.vfat -F32 /dev/nvme0n1p1

cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup luksOpen /dev/nvme0n1p2 nvme0n1p2-crypt

pvcreate /dev/mapper/nvme0n1p2-crypt
vgcreate vg0 /dev/mapper/nvme0n1p2-crypt
lvcreate -L 32G vg0 -n swap
lvcreate -l 100%FREE vg0 -n root
mkswap /dev/mapper/vg0-swap
mkfs.ext4 /dev/mapper/vg0-root

mount /dev/mapper/vg0-root /mnt
mkdir /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
swapon /dev/mapper/vg0-swap

# Install base system
pacstrap /mnt base base-devel intel-ucode linux linux-firmware lvm2 systemd-resolvconf openssh wget nano git

# Copy mirrorlist to installed base system
genfstab -pU /mnt >> /mnt/etc/fstab

# Set /tmp as temp drive
echo "tmpfs	/tmp	tmpfs	defaults,noatime,mode=1777	0	0" >> /mnt/etc/fstab

# Chroot in
arch-chroot /mnt

# Unmount and reboot into installed system
umount -R /mnt
swapoff -a
reboot
