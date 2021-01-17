#!/bin/bash
hostname="hostname"
user="user"
sshuser="sshuser"
dns="192.168.1.1 1.1.1.1 8.8.8.8 1.0.0.1 8.8.4.4" # space separated

# Set region, locale and time synchronisation
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=uk" > /etc/vconsole.conf
localectl set-keymap uk
timedatectl set-ntp true

# Create dhcp ethernet connection
cat ./Configs/20-ethernet-dhcp.network >/etc/systemd/network/20-ethernet-dhcp.network
sed -i -e "s/\$interface/""$(ls /sys/class/net/ | grep "^en")""/g" /etc/systemd/network/20-ethernet-dhcp.network

# Set hostname
hostnamectl set-hostname "$hostname"
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
groupadd "$user"
useradd -m -g "$user" -G users,wheel,storage,power,audio,autologin "$user"
passwd "$user"
gpasswd -a "$user" autologin
echo "$sshuser ALL=(ALL) ALL, NOPASSWD: /usr/bin/pacman, NOPASSWD: /usr/bin/virsh, NOPASSWD: /usr/bin/shutdown, NOPASSWD: /usr/bin/reboot" > /etc/sudoers.d/"$sshuser"
chmod 0400 /etc/sudoers.d/"$sshuser"

# Config for vfio reservation, blacklist nVidia driver and suppress msrs messages
echo "options vfio-pci ids=10de:1b06,10de:10ef" >/etc/modprobe.d/vfio.conf
echo "blacklist nouveau" >/etc/modprobe.d/blacklist.conf
echo "options kvm report_ignored_msrs=0" >/etc/modprobe.d/kvm.conf

# Add modules and hooks to mkinitcpio and generate
sed -i -e "s/MODULES=.*/MODULES=(nls_cp437 vfat vfio_pci vfio vfio_iommu_type1 vfio_virqfd i915)/g; \
           s/HOOKS=.*/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard)/g; \
           s/#COMPRESSION=\"xz\"/COMPRESSION=\"xz\"/g; \
           s/#COMPRESSION_OPTIONS=()/COMPRESSION_OPTIONS=(-0 -T 0)/g" \
           /etc/mkinitcpio.conf
mkinitcpio -P

# Setup bootloader
bootctl install
mkdir -p /etc/pacman.d/hooks
cat ./Configs/100-systemd-boot.hook >/etc/pacman.d/hooks/100-systemd-boot.hook
cat ./Configs/loader.conf >/boot/loader/loader.conf
cat ./Configs/arch.conf >/boot/loader/entries/arch.conf

encryptuuid=$(blkid | grep crypto_LUKS | grep 1n1p2 | awk -F '"' '{print $2}')
sed -i -e "s/\$encryptuuid/""$encryptuuid""/g" /boot/loader/entries/arch*.conf

# Configure quiet boot
cat ./Configs/systemd-fsck-root.service >/etc/systemd/system/systemd-fsck-root.service
cat ./Configs/systemd-fsck\@.service >/etc/systemd/system/systemd-fsck\@.service
echo "kernel.printk = 3 3 3 3" > /etc/sysctl.d/20-quiet-printk.conf

# Configure SSH
cat ./Configs/sshd_config >/etc/ssh/sshd_config
sed -i -e "s/\$sshusers/""$sshuser""/g" /etc/ssh/sshd_config
mkdir /home/"$user"/.ssh
read -n 1 -s -r -p "Switch to another TTY and add the SSH key for $sshuser. Press any key to continue..."

( cd /home/$user
chmod 0700 .ssh
chmod 0600 .ssh/*
chown -R "$user":"$user" .ssh )

# Fix system freezes when copying lots of/huge files
cat ./Configs/10-copying.conf >/etc/sysctl.d/10-copying.conf

# Enable networking and SSH
systemctl enable systemd-networkd \
                 systemd-resolved \
                 sshd

# Exit chroot
exit
