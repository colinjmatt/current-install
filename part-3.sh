#!/bin/bash
user="user" # single user only
paruuser="paruuser"
hostname="hostname"
domain="x.local"
ipaddress="192.168.1.x"
dns="192.168.1.1; 1.1.1.1; 8.8.8.8; 1.0.0.1; 8.8.4.4" # semi-colon separated multiples
gateway="192.168.1.1"
printerip="192.168.1.120"



localectl set-keymap uk
timedatectl set-ntp true
hostnamectl set-hostname "$hostname"

# Add DNS server(s)
IFS=';' read -ra DNS_ARRAY <<< "$dns"
for server in "${DNS_ARRAY[@]}"; do
  echo "nameserver $server" >> /etc/resolv2.conf
done

# Arch key servers are bad
echo "keyserver hkps://keys.openpgp.org" >>/etc/pacman.d/gnupg/gpg.conf

# All currently required software in official repos
pacman -Sy
pacman -S --noconfirm \
  alsa-plugins alsa-utils \
  bluez bluez-utils \
  ccache code cpupower cups cups-pdf \
  discord djvulibre dmidecode dosfstools \
  edk2-ovmf exfatprogs \
  fastfetch ffmpegthumbs ffnvcodec-headers firefox fuse2 \
  haveged helvum hidapi htop hunspell-en_gb \
  i2c-tools \
  kdeconnect kdenetwork-filesharing kdegraphics-thumbnailers kde-applications-meta kde-gtk-config \
  libreoffice-fresh libva-utils libva-nvidia-driver libvdpau-va-gl libxcrypt-compat libxnvctrl libva-mesa-driver libvirt \
  nvidia-open nvidia-settings net-tools network-manager-applet networkmanager networkmanager-openvpn \
  noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra ntfs-3g \
  openrgb \
  p7zip pacman-contrib phonon-qt6-vlc pigz pipewire pipewire-alsa pipewire-jack pipewire-pulse pipewire-zeroconf \
  plasma-login-manager plasma-browser-integration plasma-meta \
  powerdevil power-profiles-daemon print-manager python-hid python-psutil python-pyusb \
  qemu-desktop qt5-svg qt5-wayland \
  reflector rsync \
  sane sddm-kcm sonnet sshfs swtpm system-config-printer sysstat \
  tesseract tesseract-data-eng ttf-liberation \
  unrar unzip usbutils \
  virt-manager \
  wmctrl \
  xdg-desktop-portal xdg-desktop-portal-gtk \
  zip

# Configure reflector
cat ./Configs/mirrorupgrade.hook >/etc/pacman.d/hooks/mirrorupgrade.hook

# Optimise AUR compiles
sed -i -e "\
  s/BUILDENV=.*/BUILDENV=(\!distcc color ccache check \!sign)/g; \
  s/#MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/g" \
/etc/makepkg.conf

# Steam
pacman -S --noconfirm \
  lib32-fontconfig lib32-gamemode lib32-libva-mesa-driver lib32-libnm lib32-mesa lib32-mesa-utils lib32-nvidia-utils lib32-systemd steam
echo "unShaderBackgroundProcessingThreads $(nproc)" > /home/"$user"/.local/share/Steam/steam_dev.cfg
chown "$user":"$user" /home/"$user"/.local/share/Steam/steam_dev.cfg
su "$user" -P -c 'steamtinkerlaunch compat add'

# Install AUR helper of the month (as a non-priviledged user) and install AUR software
( cd /tmp || return
su "$paruuser" -P -c 'git clone https://aur.archlinux.org/paru.git'
cd /tmp/paru || return
su "$paruuser" -P -c 'makepkg -si --noconfirm; \
  paru -S --noconfirm \
  brother-dcp-9020cdw brscan4 \
  github-desktop gnome-icon-theme gnome-icon-theme-extras gnome-icon-theme-symbolic \
  headsetcontrol headset-charge-indicator heroic-games-launcher-bin \
  i2c-nct6775-dkms \
  numix-circle-icon-theme-git numix-icon-theme-git \
  protontricks proton-ge-custom-bin protonup-qt-bin \
  realvnc-vnc-server realvnc-vnc-viewer \
  steamtinkerlaunch sunshine \
  ttf-ms-fonts \
  uxplay \
  virtio-win')

# Blacklist nouveau
cat ./Configs/blacklist-nouveau.conf >/etc/modprobe.d/blacklist-nouveau.conf

# Gaming enhancements
cat ./Configs/90-vm-and-scheduler.conf >/etc/tmpfiles.d/90-vm-and-scheduler.conf

# Setup scanner
echo "$printerip" >> /etc/sane.d/net.conf
brsaneconfig4 -a name=BROTHER-DCP-9020CDW model=DCP-9020CDW ip="$printerip"

# Set user to autologin
mkdir -p /etc/sddm.conf.d/
cat ./Configs/sddm-autologin.conf > /etc/sddm.conf.d/autologin.conf
sed -i "s/User=.*/User=""$user""/g" /etc/sddm.conf.d/autologin.conf

# Configure QEMU and libvirt
cat ./Configs/qemu.conf >>/etc/libvirt/qemu.conf
sed -i -e "s/\user.*/user\ =\ \"""$user""\"/g" /etc/libvirt/qemu.conf
usermod -a -G input,kvm,libvirt,render $user

mkdir -p /etc/libvirt/{devices,storage,hooks}

# CPU set to performance and GPU preparation via hooks
cat ./Configs/qemu >/etc/libvirt/hooks/qemu
chmod +x /etc/libvirt/hooks/qemu
mkdir -p /etc/libvirt/hooks/qemu.d/win-gaming/prepare/begin/
mkdir -p /etc/libvirt/hooks/qemu.d/win-gaming/release/end/
cat ./Configs/libvirt-start.sh >/etc/libvirt/hooks/qemu.d/win-gaming/prepare/begin/start.sh
cat ./Configs/libvirt-end.sh >/etc/libvirt/hooks/qemu.d/win-gaming/release/end/end.sh
chmod -R +x /etc/libvirt/hooks/

# Disable sp5100 watchdog
cat ./Configs/disable-sp5100-watchdog.conf >/etc/modprobe.d/disable-sp5100-watchdog.conf

# Storage options for virt-manager
cat ./Configs/Virtio.xml >/etc/libvirt/storage/Virtio.xml
cat ./Configs/Windows.xml >/etc/libvirt/storage/Windows.xml
ln -s /etc/libvirt/storage/Virtio.xml /etc/libvirt/storage/autostart/Virtio.xml
ln -s /etc/libvirt/storage/Windows.xml /etc/libvirt/storage/autostart/Windows.xml

# VM Network
cat ./Configs/libvirt-default.xml >/etc/libvirt/qemu/networks/default.xml
ln -sf /etc/libvirt/qemu/networks/default.xml /etc/libvirt/qemu/networks/autostart/default.xml

# VM configs
cat ./Configs/win-gaming.xml >/etc/libvirt/qemu/win-gaming.xml
cat ./Configs/win-work.xml >/etc/libvirt/qemu/win-work.xml

# Create SSL keys for Spice
( mkdir /etc/pki
mkdir /etc/pki/qemu
cd /etc/pki/qemu || return
openssl genrsa -out ca-key.pem 1024
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
nmcli_dns="${dns//; / }"
nmcli connection add type bridge con-name "Host Bridge" ifname virbr0
nmcli connection modify "Host Bridge" \
  ipv4.addresses "$ipaddress/24" \
  ipv4.gateway "$gateway" \
  ipv4.dns "$nmcli_dns" \
  ipv4.dns-search "$domain" \
  ipv4.method "manual"
nmcli connection modify "Host Bridge" bridge.stp no
nmcli connection modify "Host Bridge" bridge.forward-delay 0

# Make autostart directory if it doesn't exist
mkdir -p /home/"$user"/.config/autostart

# Headset Control
cat ./Configs/HeadsetControl.desktop >/home/"$user"/.config/autostart/HeadsetControl.desktop
cat ./Configs/Arctis7PlusChatMix.py >/usr/local/bin/Arctis7PlusChatMix.py
cat ./Configs/99-arctis7plus.rules >/etc/udev/rules.d/99-arctis7plus.rules
sed -i -e "s/\$user/""$user""/g" /etc/udev/rules.d/99-arctis7plus.rules
cat ./Configs/Arctis7PlusChatMix.desktop >/home/"$user"/.config/autostart/Arctis7PlusChatMix.desktop

# OpenRGB
cat ./Configs/60-openrgb.rules > /etc/udev/rules.d/60-openrgb.rules
cat ./Configs/OpenRGB.desktop >/home/"$user"/.config/autostart/OpenRGB.desktop
mkdir -p /home/"$user"/.config/OpenRGB
cat ./Configs/openrgb-Default >/home/"$user"/.config/OpenRGB/openrgb-Default

# Steam friends list positioning
cat ./Configs/SteamFriendsListPosition.desktop >/home/"$user"/.config/autostart/SteamFriendsListPosition.desktop
cat ./Configs/wmctl-friendslist.sh >/usr/local/bin/wmctl-friendslist.sh

# Sunshine
cat ./Configs/Sunshine.desktop >/home/"$user"/.config/autostart/Sunshine.desktop

# UXPlay
cat ./Configs/UXPlay.desktop >/home/"$user"/.config/autostart/UXPlay.desktop

# Yakuake
cat ./Configs/Yakuake.desktop >/home/"$user"/.config/autostart/Yakuake.desktop

# Enable backups
cat ./Configs/backup.sh >/usr/local/bin/backup.sh
sed -i -e "s/\$user/""$user""/g" /usr/local/bin/backup.sh
read -n 1 -s -r -p "Switch to another TTY and complete the backup script variables. Press any key to continue..."
cat ./Configs/backup.service >/etc/systemd/system/backup.service
cat ./Configs/backup.timer >/etc/systemd/system/backup.timer

# Set permissions
chmod +x -R /usr/local/bin/*
chown -R "$user":"$user" /home/"$user"/.config/autostart

# Set max journal size for systemd-journald
echo "SystemMaxUse=50M" >>/etc/systemd/journald.conf

# Disable initial networking services
systemctl disable systemd-networkd \
                  systemd-resolved

# Enable ALL the services
systemctl enable avahi-daemon \
                 backup.timer \
                 bluetooth \
                 cpupower \
                 cups \
                 fstrim.timer \
                 haveged \
                 libvirtd \
                 NetworkManager \
                 nvidia-persistenced \
                 sddm \
                 systemd-oomd \
                 systemd-timesyncd \
                 virtlogd.socket 

reboot