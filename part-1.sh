#!/bin/bash
# BACKUP /home/user/    BEFORE REINSTALLING!!
# BACKUP /etc/libvirt/  BEFORE REINSTALLING!!

# Set keyboard map & time sync
loadkeys uk
timedatectl set-ntp true

# Sort the mirrorlist so downloads are fast enough and from teh correct location
reflector --country 'United Kingdom' --protocol https --latest 50 --fastest 8 --age 24 --sort rate --save /etc/pacman.d/mirrorlist

# Create partitions, create and open encrypted volume and mount all partitions
#parted -s /dev/nvme0n1 mklabel gpt
#parted -s /dev/nvme0n1 mkpart ESP fat32 2048s 512MiB
#parted -s /dev/nvme0n1 mkpart primary ext4 512MiB 100%
#parted -s /dev/nvme0n1 set 1 boot on

#cryptsetup luksFormat /dev/nvme0n1p2
#cryptsetup luksOpen /dev/nvme0n1p2 nvme0n1p2-crypt
#pvcreate /dev/mapper/nvme0n1p2-crypt
#vgcreate vg0 /dev/mapper/nvme0n1p2-crypt
#lvcreate -L 64G vg0 -n swap
#lvcreate -L 128G vg0 -n root
#lvcreate -l 100%FREE vg0 -n vms

#mkfs.vfat -F32 /dev/nvme0n1p1
#mkswap /dev/mapper/vg0-swap
#mkfs.ext4 /dev/mapper/vg0-root
#mkfs.ext4 /dev/mapper/vg0-vms

#mount /dev/mapper/vg0-root /mnt
#mkdir -p /mnt/boot
#mount /dev/nvme0n1p1 /mnt/boot
#swapon /dev/mapper/vg0-swap

#mkdir -p /mnt/mnt/{Games,VMs}
#mount /dev/nvme1n1p1 /mnt/mnt/Games
#mount /dev/mapper/vg0-vms /mnt/mnt/VMs

# Create Paritions - NON ENCRYPTED VERSION
parted -s /dev/nvme0n1 mklabel gpt
parted -s /dev/nvme0n1 mkpart ESP fat32 2048s 512MiB
parted -s /dev/nvme0n1 mkpart linux-swap ext4 512MiB 66048MiB
parted -s /dev/nvme0n1 mkpart primary ext4 66048MiB 197120MiB
parted -s /dev/nvme0n1 mkpart primary ext4 197120MiB 100%

parted -s /dev/nvme0n1 set 1 boot on
mkfs.vfat -F32 /dev/nvme0n1p1
mkswap /dev/nvme0n1p2
mkfs.ext4 /dev/nvme0n1p3
mkfs.ext4 /dev/nvme0n1p4

mount /dev/nvme0n1p3 /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
swapon /dev/nvme0n1p2

mkdir -p /mnt/mnt/{Games,VMs}
mount /dev/nvme1n1p1 /mnt/mnt/Games
mount /dev/nvme0n1p4 /mnt/mnt/VMs

# Install system - 'lvm' needed for encryption
pacstrap /mnt base base-devel amd-ucode linux linux-firmware linux-headers nvidia systemd-resolvconf openssh wget nano git

# Generate fstab for filesystem mounts and add /tmp as ram drive
genfstab -pU /mnt >>/mnt/etc/fstab
echo "tmpfs	/tmp	tmpfs	defaults,noatime,mode=1777	0	0" >>/mnt/etc/fstab
sed -i -e "s/fmask=0022,dmask=0022/fmask=0077,dmask=0077/g" /mnt/etc/fstab

# Copy mirrorlist to installed base system
cat /etc/pacman.d/mirrorlist >/mnt/etc/pacman.d/mirrorlist

# Chroot in
arch-chroot /mnt

# Unmount and reboot into installed system
umount -R /mnt
swapoff -a
reboot
