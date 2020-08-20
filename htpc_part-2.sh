#!/bin/bash
hostname="hostname"
user="user"
yayuser="yayuser" # Will be used to install packages and will be added to sudoers
domain="localdomain" # single value
ipaddress="0.0.0.0\/24" # single value, backslash is intentional
dns="1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4" # space separated multiples
gateway="0.0.0.0" # single value


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

# Create static ethernet connection
cat ./Configs/10-ethernet-static.network >/etc/systemd/network/10-ethernet-static.network
sed -i -e " \
  s/\$interface/""$(echo /sys/class/net/en* | cut -d / -f 5 | xargs printf %s)""/g; \
  s/\$ipaddress/""$ipaddress""/g; \
  s/\$gateway/""$gateway""/g; \
  s/\$dns/""$dns""/g; \
  s/\$domain/""$domain""/g" \
/etc/systemd/network/10-ethernet-static.network

# Add DNS server(s) and enable networking
for server in $dns; do
  echo "DNS=$server" >> /etc/systemd/network/10-ethernet-static.network
done

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

groupadd "$yayuser"
useradd -m -g "$yayuser" -G users,wheel,storage,power,audio "$yayuser"
passwd "$yayuser"
echo "$yayuser ALL=(ALL) ALL, NOPASSWD: /usr/bin/pacman, NOPASSWD: /usr/bin/virsh, NOPASSWD: /usr/bin/shutdown, NOPASSWD: /usr/bin/reboot" > /etc/sudoers.d/"$yayuser"
chmod 0400 /etc/sudoers.d/"$yayuser"

# Add modules and hooks to mkinitcpio and generate
sed -i -e " \
  s/HOOKS=.*/HOOKS=(base systemd fsck autodetect modconf block filesystems keyboard)/g; \
  s/#COMPRESSION=\"xz\"/COMPRESSION=\"xz\"/g; \
  s/#COMPRESSION_OPTIONS=()/COMPRESSION_OPTIONS=(-0 -T 0)/g" \
/etc/mkinitcpio.conf
mkinitcpio -P

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
sed -i -e "s/\$yayuser/""$yayuser""/g" /etc/ssh/sshd_config
read -n 1 -s -r -p "Switch to another TTY and add the SSH key for $yayuser. Press any key to continue..."

# Fix system freezes when copying lots of/huge files
cat ./Configs/10-copying.conf >/etc/sysctl.d/10-copying.conf

# Enable networking
systemctl enable systemd-networkd systemd-resolved sshd

# Exit chroot
exit
