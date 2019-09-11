#!/bin/bash
user=""
hostname=""
domain=""
dns=""
fallbackdns=""

# Create and mount swapfile
dd if=/dev/zero of=/mnt/swapfile bs=1M count=2048
chown root:root /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile
echo "/mnt/swapfile swap swap defaults 0 0" >> /etc/fstab
swapon -a

# /tmp uses tmpfs
echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab

# Start wifi
netctl enable wlan0
netctl start wlan0

# Set locale
echo "en_GB.UTF-8 UTF-8" >/etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" >/etc/locale.conf
localectl set-locale LANG="en_GB.UTF-8"

# Set timezone and enable ntp
rm /etc/localtime
ln -s /usr/share/zoneinfo/Europe/London /etc/localtime
timedatectl set-ntp true

# Set hostname
hostname $hostname
echo "$hostname" >/etc/hostname
echo "127.0.0.1 localhost.localdomain localhost $hostname" > /etc/hosts

# Set .bashrc & .nanorc configuration
cat ./Configs/root_bashrc >/etc/bash.bashrc
cat ./Configs/user_bashrc >/etc/skel/.bashrc

cat ./Configs/root_nanorc >/root/.nanorc
cat ./Configs/user_nanorc >/etc/skel/.nanorc
cat ./Configs/nanorc >/etc/nanorc

# Configure pacman
cat ./PiConfigs/pacman.conf >/etc/pacman.conf
pacman-key --init
pacman-key --populate archlinuxarm

# Install yay
cd /tmp || return
git clone https://aur.archlinux.org/yay.git
cd /tmp/yay || return
makepkg -si

# Install packages
pacman -S base-devel sudo dnsutils rsync python-pip git i2c-tools lm_sensors nfs-utils
yay -S pi-bluetooth python-raspberry-gpio raspi-config
pip install touchphat

# Experimental patch for bluetooth to work with wifi
cat ./PiConfigs/sdio.txt >>/usr/lib/firmware/updates/brcm/brcmfmac43430-sdio.txt
cat ./PiConfigs/sdio.txt >>/usr/lib/firmware/updates/brcm/brcmfmac43455-sdio.txt

# Configure i2c & spi
echo "device_tree_param=spi=on" >>/boot/config.txt
echo "dtparam=i2c_arm=on" >>/boot/config.txt
echo -e "i2c-dev\ni2c-bcm2708" >>/etc/modules-load.d/raspberrypi.conf
cat ./PiConfigs/99-spi-permissions.rules >/usr/lib/udev/rules.d:99-spi-permissions.rules

# Password set for root and create the main user
passwd root
groupadd $user
useradd -m -g $user -G users,wheel,storage,power,audio $user
echo "$user ALL=(ALL) ALL, NOPASSWD: /usr/bin/pacman, NOPASSWD: /usr/bin/shutdown, NOPASSWD: /usr/bin/reboot" > /etc/sudoers.d/$user
chmod 0400 /etc/sudoers.d/$user

# Configure ssh
cat ./Configs/sshd_config >/etc/sshd/sshd_config
sed -i -e "s/\$user/""$user""/g"

# Remove unneeded alarm user
userdel alarm
rm -rf /home/alarm

# Set domain for ID mapping on NFS
sed -i -e "s/#Domain\ =.*/Domain\ =\ ""$domain""/g" /etc/idmapd.conf

# Set DNS servers
cat ./PiConfigs/resolved.conf >/etc/systemd/resolved.conf
sed -i -e "s/\$dns/""$dns""/g s/\$fallbackdns/""$fallbackdns""/g s/\$domain/""domain""/g" /etc/systemd/resolved.conf

# Create touchphat script service
cat ./PiConfigs/pHAT_functions.service >/etc/systemd/system/pHAT_functions.service
cat ./PiConfigs/pHAT_functions.py >/usr/local/bin/pHAT_functions.py

# Create backup service
cat ./PiConfigs/backup.sh >/usr/local/bin/backup.sh
sed -i -e "s/\$backupuser/""$backupuser""/g" /usr/local/bin/backup.sh
cat ./PiConfigs/rsync_backup.timer >/etc/systemd/system/rsync_backup.timer
cat ./PiConfigs/rsync_backup.service >/etc/systemd/system/rsync_backup.service

# Creat eupdate service
cat ./PiConfigs/pacman.sh >/usr/local/bin/pacman.sh
cat ./PiConfigs/auto_pacman.service /etc/systemd/auto_pacman.service
cat ./PiConfigs/auto_pacman.timer /etc/systemd/auto_pacman.timer

# Make all copied scripts executable
chmod +x /usr/local/bin/*.sh

# lvm2 is not used and doesn't need monitoring
systemctl mask lvm2-monitor

# Enable stuff
systemctl enable    auto_pacman.timer \
                    pHAT_functions \
                    rsync_backup.timer

reboot
