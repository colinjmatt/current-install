#!/bin/bash
# BACKUP /home/user/    BEFORE REINSTALLING!!
# BACKUP /etc/libvirt/  BEFORE REINSTALLING!!

# Set keyboard map & time sync
loadkeys uk
timedatectl set-ntp true

# Sort the mirrorlist so downloads are fast enough and from teh correct location
reflector --country 'United Kingdom' --protocol https --latest 50 --fastest 8 --age 24 --sort rate --save /etc/pacman.d/mirrorlist

# Create partitions, create and open encrypted volume and mount all partitions
parted -s /dev/nvme1n1 mklabel gpt
parted -s /dev/nvme1n1 mkpart ESP fat32 2048s 512MiB
parted -s /dev/nvme1n1 set 1 boot on
parted -s /dev/nvme1n1 mkpart primary ext4 512MiB 100%
mkfs.vfat -F32 /dev/nvme1n1p1

cryptsetup luksFormat /dev/nvme1n1p2
cryptsetup luksOpen /dev/nvme1n1p2 nvme1n1p2-crypt

pvcreate /dev/mapper/nvme1n1p2-crypt
vgcreate vg0 /dev/mapper/nvme1n1p2-crypt
lvcreate -L 64G vg0 -n swap
lvcreate -L 128G vg0 -n root
lvcreate -l 100%FREE vg0 -n vms
mkswap /dev/mapper/vg0-swap
mkfs.ext4 /dev/mapper/vg0-root
mkfs.ext4 /dev/mapper/vg0-vms

mount /dev/mapper/vg0-root /mnt
mkdir /mnt/boot
mount /dev/nvme1n1p1 /mnt/boot
swapon /dev/mapper/vg0-swap

# Install base system
pacstrap /mnt base base-devel intel-ucode linux linux-firmware lvm2 systemd-resolvconf openssh wget nano git

mkdir /mnt/mnt/VMs
mount /dev/mapper/vg0-vms /mnt/mnt/VMs

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
