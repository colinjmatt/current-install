#!/bin/bash
hostname="hostname"
user="user"
yayuser="yayuser"
sshuser="yayuser"
dns="1.1.1.1 1.0.0.1" # space separated multiples

# Set region, locale and time synchronisation
rm /etc/localtime
ln -s /usr/share/zoneinfo/Europe/London /etc/localtime
echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
export LANG=en_GB.UTF-8
echo "KEYMAP=uk" > /etc/vconsole.conf
localectl set-keymap uk
localectl set-locale LANG="en_GB.UTF-8"
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
useradd -m -g "$yayuser" -G users,wheel,storage,power,audio "$yayuser"
passwd "$yayuser"
echo "$sshuser ALL=(ALL) ALL, NOPASSWD: /usr/bin/pacman, NOPASSWD: /usr/bin/virsh, NOPASSWD: /usr/bin/shutdown, NOPASSWD: /usr/bin/reboot" > /etc/sudoers.d/"$sshuser"
chmod 0400 /etc/sudoers.d/"$sshuser"

# Add modules and hooks to mkinitcpio and generate
sed -i "s/HOOKS=.*/HOOKS=(base systemd fsck autodetect modconf block filesystems keyboard)/g" /etc/mkinitcpio.conf
mkinitcpio -p linux

# Setup bootloader
bootctl install
mkdir -p /etc/pacman.d/hooks
cat ./Configs/100-systemd-boot.hook >/etc/pacman.d/hooks/100-systemd-boot.hook
cat ./Configs/loader.conf >/boot/loader/loader.conf
cat ./HTPCConfigs/arch.conf >/boot/loader/entries/arch.conf

uuid=$(blkid | grep sda3 | awk -F '"' '{print $2}')
sed -i -e "s/\$uuid/""$uuid""/g" /boot/loader/entries/arch.conf

# Configure quiet boot
cat ./Configs/systemd-fsck-root.service >/etc/systemd/system/systemd-fsck-root.service
cat ./Configs/systemd-fsck\@.service >/etc/systemd/system/systemd-fsck\@.service
echo "kernel.printk = 3 3 3 3" > /etc/sysctl.d/20-quiet-printk.conf

# Configure SSH
cat ./Configs/sshd_config >/etc/ssh/sshd_config
sed -i -e "s/\$sshusers/""$sshusers""/g" /etc/ssh/sshd_config
read -n 1 -s -r -p "Switch to another TTY and add the SSH key for $sshuser. Press any key to continue..."

# Fix system freezes when copying lots of/huge files
cat ./Configs/10-copying.conf >/etc/sysctl.d/10-copying.conf

# Add DNS server(s) and enable networking
for server in $dns; do
  echo "nameserver $server" >> /etc/resolv.conf
done
systemctl enable systemd-networkd systemd-resolved sshd

# Exit chroot
exit
