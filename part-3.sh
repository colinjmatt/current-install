#!/bin/bash
user="user" # single
hostname="hostname" # single
domain="x.local" # single
ipaddress="192.168.0.x" # single
dns="x.x.x.x; 1.1.1.1; 1.0.0.1" # semi-colon separated multiples
gateway="192.168.0.1" # single
printerip="192.168.0.120" # single
vnclicense="" # single
backupuser="backup-user"

# All currently required software in official repos
pacman -S \
  xorg-server xorg-xrandr xorg-xinput xdg-utils xterm \
  firewalld ebtables dnsutils net-tools bridge-utils \
  networkmanager networkmanager-openvpn network-manager-applet \
  xfce4 xfce4-goodies lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings gtk-engine-murrine \
  accountsservice slock ffmpegthumbnailer raw-thumbnailer gnome-keyring \
  alsa-utils pulseaudio pulseaudio-alsa pavucontrol pasystray paprefs audacity \
  nfs-utils exfat-utils ntfs-3g gvfs sshfs dosfstools parted gnome-disk-utility \
  p7zip zip unzip unrar file-roller \
  elementary-icon-theme \
  noto-fonts noto-fonts-emoji noto-fonts-extra noto-fonts-cjk ttf-liberation \
  cups cups-pdf sane gscan2pdf djvulibre tesseract tesseract-data-eng \
  firefox epdfview libreoffice-fresh discord bleachbit \
  qemu libvirt libgsf virt-manager \
  vulkan-intel iasl libva-intel-driver gst-libav libvdpau-va-gl \
  rsync ccache speedtest-cli \
  polkit reflector cpupower haveged neofetch

# Configure reflector
echo "COUNTRY=UK" >/etc/conf.d/reflector.conf
cat ./Configs/10-mirrorupgrade.hook >/etc/pacman.d/hooks/10-mirrorupgrade.hook

# Set X keymap
localectl set-x11-keymap gb

# Optimise AUR compiles
sed -i "s/BUILDENV=.*/BUILDENV=(fakeroot \!distcc color ccache check \!sign)/g" /etc/makepkg.conf
sed -i "s/#MAKEFLAGS=.*/MAKEFLAGS=\"-j13\"/g" /etc/makepkg.conf

# Install yay (as a non-priviledged user)
( cd /tmp || return
su $user -P -c 'git clone https://aur.archlinux.org/yay.git'
cd /tmp/yay || return
su $user -P -c 'makepkg -si' )

# All currently required software in AUR
( su $user -P -c 'yay -S \
  linux-rt-bfq \
  xfce4-volumed-pulse mugshot \
  p7zip-gui \
  arc-icon-theme-git faba-icon-theme-git moka-icon-theme-git \
  ttf-ms-fonts \
  brother-dcp-9020cdw brscan4 \
  realvnc-vnc-server realvnc-vnc-viewer \
  ovmf-git virtio-win dmidecode-git scream-pulse \
  g810-led-git krakenx' )

# Change to RT-BFQ kernel on boot
sed -i "s/default\ arch/default\ arch-rt-bfq/g" /boot/loader/loader.conf

# Setup extra partitions
cat ./Configs/crypttab >>/etc/crypttab # A keyfile needs to be generated and placed at /root/.cryptkey for this crypttab to work
cat ./Configs/fstab >> /etc/fstab
mkdir /mnt/{offsite-hetzner,VMs}
read -n 1 -s -r -p "Switch to another TTY, add /root/.cryptkey key and tidy up fstab and crypttab. Press any key to continue..."

# Setup scanner
echo "$printerip" >> /etc/sane.d/net.conf
brsaneconfig4 -a name=BROTHER-DCP-9020CDW model=DCP-9020CDW ip="$printerip"

# Set user to autologin
sed -i "s/#autologin-user=.*/autologin-user=""$user""/g" /etc/lightdm/lightdm.conf

# Configure QEMU and libvirt
cat ./Configs/qemu.conf >/etc/libvirt/qemu.conf
sed -i -e "s/\$user/""$user""/g" /etc/libvirt/qemu.conf
cat ./Configs/libvirtd.conf >/etc/libvirt/libvirtd.conf
usermod -a -G libvirt $user

# Set governor to performance when gaming VM is running to reduce latency
mkdir /etc/libvirt/hooks
cat ./Configs/qemu >/etc/libvirt/hooks/qemu
chmod +x /etc/libvirt/hooks/qemu

# Create SSL keys for Spice
( mkdir /etc/pki
mkdir /etc/pki/qemu
cd /etc/pki/qemu || return
openssl genrsa -nodes -out ca-key.pem 1024
openssl req -new -x509 -days 750 -key ca-key.pem -out ca-cert.pem -utf8 -subj "/CN=Self Signed"
openssl genrsa -out server-key.pem 1024
openssl req -new -key server-key.pem -out server-key.csr -utf8 -subj "/CN=$user"
openssl x509 -req -days 750 -in server-key.csr -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out server-cert.pem
openssl rsa -in server-key.pem -out server-key.pem.insecure
mv server-key.pem server-key.pem.secure
mv server-key.pem.insecure server-key.pem
sudo chown root:kvm ./*
sudo chmod 0440 ./* )

# Configure Network Manager
cat ./Configs/bridge-master.nmconnection >/etc/NetworkManager/system-connections/Bridge\ Master.nmconnection
sed -i -e "\
  s/\$hostname/""$hostname""/g; \
  s/\$domain/""$domain""/g; \
  s/\$ipaddress/""$ipaddress""/g; \
  s/\$dns/""$dns""/g; \
  s/\$gateway/""$gateway""/g" \
/etc/NetworkManager/system-connections/Bridge\ Master.nmconnection

cat ./Configs/bridge-slave.nmconnection >/etc/NetworkManager/system-connections/Bridge\ Slave\ "$hostname".nmconnection
enet=$(ls /sys/class/net/ | grep "^en")
sed -i -e "\
  s/\$hostname/""$hostname""/g; \
  s/\$enet/""$enet""/g" \
/etc/NetworkManager/system-connections/Bridge\ Slave\ "$hostname".nmconnection

# G810 Keyboard and Kraken profiles
cat ./Configs/g810-led-profile >/etc/g810-led/profile
cat ./Configs/krakenx-config.service >/etc/krakenx-config.service

# Enable VNC
vnclicense -add "$vnclicense"
vncinitconfig -service-daemon

# Enable backups
cat ./Configs/backup.sh >/usr/local/bin/backup.sh
read -n 1 -s -r -p "Switch to another TTY and complete the backup script variables. Press any key to continue..."
cat ./Configs/backup.service >/etc/systemd/system/backup.service
cat ./Configs/backup.timer >/etc/systemd/system/backup.timer

# Everything in /usr/local/bin is executable
chmod +x -R /usr/local/bin/*

# Disable initial networking services
systemctl disable systemd-networkd \
                  systemd-resolved

# Enable ALL the services
systemctl enable avahi-daemon \
                 haveged \
                 krakenx-config \
                 libvirtd \
                 lightdm \
                 NetworkManager \
                 org.cups.cupsd \
                 backup.timer \
                 vncserver-x11-serviced

reboot
