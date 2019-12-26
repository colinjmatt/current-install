#!/bin/bash
# BACKUP /home/user/    BEFORE REINSTALLING!!
# BACKUP /etc/libvirt/  BEFORE REINSTALLING!!

# Set time & keyboard map
timedatectl set-ntp true
loadkeys uk.map.gz

# Sort the mirrorlist so downloads are fast enough
grep --no-group-separator -A1 "United Kingdom" /etc/pacman.d/mirrorlist > /mirrorlist
cat /mirrorlist >/etc/pacman.d/mirrorlist

# Open encrypted volume and mount root partition
cryptsetup luksOpen /dev/nvme0n1p2 nvme0n1p2-crypt
mount /dev/mapper/vg0-root /mnt

# Delete all files
read -n 1 -s -r -p "Switch to another TTY and backup anything required. Press any key to continue.."
rm -rf /mnt/*

# Mount everything else and clear out boot partition
mount /dev/nvme0n1p1 /mnt/boot
rm -rf /mnt/boot/*

swapon /dev/mapper/vg0-swap

# Install base system + a few required extras
pacstrap /mnt base base-devel intel-ucode linux linux-firmware lvm2 systemd-resolvconf openssh wget nano git

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
