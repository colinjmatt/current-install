#!/bin/bash
# BACKUP /home/user/    BEFORE REINSTALLING!!
# BACKUP /etc/libvirt/  BEFORE REINSTALLING!!
hostname=""
user=""

# Set time & keyboard map
timedatectl set-ntp true
loadkeys uk.map.gz

# Sort the mirrorlist so downloads are fast enough
grep --no-group-separator -A1 "United Kingdom" /etc/pacman.d/mirrorlist > /mirrorlist
cat /mirrorlist > /etc/pacman.d/mirrorlist

# Create partitions, create and open encrypted volume and mount all partitions
parted -s /dev/nvme1n1 mklabel gpt
parted -s /dev/nvme1n1 mkpart ESP fat32 2048s 512MiB
parted -s /dev/nvme1n1 set 1 boot on
parted -s /dev/nvme1n1 mkpart primary ext4 512MiB 100%
mkfs.vfat -F32 /dev/nvme0n1p1

cryptsetup luksFormat /dev/nvme1n1p2
cryptsetup luksOpen /dev/nvme1n1p2 nvme1n1p2-crypt

pvcreate /dev/mapper/nvme1n1p2-crypt
vgcreate vg0 /dev/mapper/nvme1n1p2-crypt
lvcreate -L 32G vg0 -n swap
lvcreate -l 100%FREE vg0 -n root
mkswap /dev/mapper/vg0-swap
mkfs.ext4 /dev/mapper/vg0-root

mount /dev/mapper/vg0-root /mnt
mkdir /mnt/boot
mount /dev/nvme1n1p1 /mnt/boot
swapon /dev/mapper/vg0-swap

# Install base system
pacstrap /mnt base base-devel intel-ucode openssh wget git

# Copy mirrorlist to installed base system
cp /mirrorlist /mnt/etc/pacman.d/
genfstab -pU /mnt >> /mnt/etc/fstab

# Set /tmp as temp drive
echo "tmpfs	/tmp	tmpfs	defaults,noatime,mode=1777	0	0" >> /mnt/etc/fstab

# Chroot in
arch-chroot /mnt

# Set region and locale
rm /etc/localtime
ln -s /usr/share/zoneinfo/Europe/London /etc/localtime
echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
export LANG=en_GB.UTF-8
echo "KEYMAP=uk" > /etc/vconsole.conf

# Create dhcp ethernet connection
cat ./Configs/ethernet-dhcp >/etc/netctl/ethernet-dhcp
sed -i -e "s/\$interface/""$(ls /sys/class/net/ | grep "^en")""/g" /etc/netctl/ethernet-dhcp

# Set hostname
hostname $hostname
echo "$hostname" > /etc/hostname
echo "127.0.0.1 localhost.localdomain localhost $hostname" > /etc/hosts

# Configure pacman
cat ./Configs/pacman.conf >/etc/pacman.conf

# Set .bashrc  and .nanorc for users & root
cat ./Configs/root_bashrc >/root/.bashrc
cat ./Configs/user_bashrc >/etc/skel/.bashrc

cat ./Configs/root_nanorc >/root/.nanorc
cat ./Configs/user_nanorc >/etc/skel/.nanorc

cat ./Configs/nanorc > /etc/nanorc

# Set root password, create user, add to sudoers (enable pacaman and virsh sudo without pass) and set password
passwd root
groupadd -r autologin
groupadd $user
useradd -m -g $user -G users,wheel,storage,power,audio,autologin $user
passwd $user
gpasswd -a $user autologin
echo "$user ALL=(ALL) ALL, NOPASSWD: /usr/bin/pacman, NOPASSWD: /usr/bin/virsh, NOPASSWD: /usr/bin/shutdown, NOPASSWD: /usr/bin/reboot" > /etc/sudoers.d/$user
chmod 0400 /etc/sudoers.d/$user

# Add modules and hooks to mkinitcpio and generate
sed -i "s/MODULES=.*/MODULES=(nls_cp437 vfat vfio_pci vfio vfio_iommu_type1 vfio_virqfd i915)/g" /etc/mkinitcpio.conf
sed -i "s/HOOKS=.*/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard)/g" /etc/mkinitcpio.conf
mkinitcpio -p linux

# Setup bootctl
bootctl install
mkdir -p /etc/pacman.d/hooks
cat ./Configs/100-systemd-boot.hook >/etc/pacman.d/hooks/100-systemd-boot.hook
cat ./Configs/loader.conf >/boot/loader/loader.conf
cat ./Configs/arch.conf /boot/loader/entries/arch.conf
cat ./Configs/arch-rt-bfq.conf /boot/loader/entries/arch-rt-bfq.conf

LUKSENCRYPTUUID=$(blkid | grep crypto_LUKS | awk -F '"' '{print $2}')
sed -i -e "s/\$LUKSENCRYPTUUID/""$LUKSENCRYPTUUID""/g"

# Config for vfio reservation, blacklist nVidia driver and quiet kernel
echo "options vfio-pci ids=10de:1b06,10de:10ef" > /etc/modprobe.d/vfio.conf
echo "blacklist nouveau" > /etc/modprobe.d/blacklist.conf
echo "kernel.printk = 3 3 3 3" > /etc/sysctl.d/20-quiet-printk.conf

# Setup fsck after kernel load due to being removed for quiet boot
cat ./Configs/systemd-fsck-root.service >/etc/systemd/system/systemd-fsck-root.service
cat ./Configs/systemd-fsck\@.service >/etc/systemd/system/systemd-fsck\@.service

# Enable and start networking to download more packages
systemctl enable netctl
netctl enable ethernet-dhcp

# Exit chroot and reboot into installed system
exit
umount -R /mnt
swapoff -a
reboot
