#!/bin/bash
user="user" # single user only
paruuser=""
hostname="hostname"
machine="machine" # Friendly computer name for airplay stuff
domain="x.local"
ipaddress="192.168.1.x"
dns="192.168.1.1; 1.1.1.1; 8.8.8.8; 1.0.0.1; 8.8.4.4" # semi-colon separated multiples
gateway="192.168.1.1"
printerip="192.168.1.120"

dns2="${dns//;}"

localectl set-keymap uk
timedatectl set-ntp true
hostnamectl set-hostname "$hostname"

# Add DNS server(s)
for server in $dns2; do
  echo "nameserver $server" >> /etc/resolv.conf
done
echo "DNS=$dns2" >> /etc/systemd/resolved.conf

# Arch key servers are bad
echo "keyserver hkps://keys.openpgp.org" >>/etc/pacman.d/gnupg/gpg.conf

# All currently required software in official repos
pacman -Sy
pacman -S --noconfirm \
  accountsservice alsa-plugins alsa-utils \
  blueman bluez bluez-utils bridge-utils \
  ccache cpupower cups cups-pdf \
  discord djvulibre dmidecode dnsmasq dnsutils dosfstools \
  edk2-ovmf exfat-utils \
  ffmpegthumbnailer ffnvcodec-headers file-roller firefox firewalld fuse2 \
  gnome-disk-utility gnome-keyring gscan2pdf gspell gst-libav gst-plugin-pipewire gstreamer-vaapi \
  gtk-engine-murrine gvfs gvfs-smb \
  haveged helvum htop hunspell-en_gb \
  i2c-tools \
  libgsf libopenraw libreoffice-fresh libva-utils libva-vdpau-driver libvdpau-va-gl libxcrypt-compat \
  libxnvctrl libva-mesa-driver libvirt lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings lutris \
  mesa mesa-vdpau  \
  nvidia-settings nvidia-utils \
  neofetch net-tools network-manager-applet networkmanager networkmanager-openvpn noto-fonts \
  noto-fonts-cjk noto-fonts-emoji noto-fonts-extra nss-mdns ntfs-3g \
  openrgb \
  p7zip pacman-contrib paprefs parted pasystray pavucontrol polkit poppler poppler-data pipewire \
  pipewire-alsa pipewire-jack pipewire-pulse pipewire-x11-bell pipewire-zeroconf python-psutil python-pyusb \
  qemu-desktop \
  reflector rsync \
  sane seahorse shairplay slock speedtest-cli sshfs swtpm sysstat \
  tesseract tesseract-data-eng ttf-liberation \
  unrar unzip usbutils \
  virt-manager \
  wireplumber \
  xdg-user-dirs xdg-utils xfce4 xfce4-goodies xorg-server xorg-xinput xorg-xrandr xterm \
  zip

# Configure reflector
cat ./Configs/mirrorupgrade.hook >/etc/pacman.d/hooks/mirrorupgrade.hook

# Set X keymap
localectl set-x11-keymap gb

# Optimise AUR compiles
sed -i -e "\
  s/BUILDENV=.*/BUILDENV=(fakeroot \!distcc color ccache check \!sign)/g; \
  s/#MAKEFLAGS=.*/MAKEFLAGS=\"-j33\"/g" \
/etc/makepkg.conf

# Install AUR helper of the month (as a non-priviledged user) and install AUR software
( cd /tmp || return
su "$paruuser" -P -c 'git clone https://aur.archlinux.org/paru-bin.git'
cd /tmp/paru-bin || return
su "$paruuser" -P -c 'makepkg -si --noconfirm; \
  paru -S --noconfirm \
  brother-dcp-9020cdw brscan4 \
  epdfview-git \
  headsetcontrol headset-charge-indicator heroic-games-launcher-bin \
  i2c-nct6775-dkms \
  mugshot \
  numix-circle-icon-theme-git numix-icon-theme-git \
  p7zip-gui \
  realvnc-vnc-server realvnc-vnc-viewer rpiplay \
  ttf-ms-fonts \
  virtio-win \
  xfce4-volumed-pulse')

# Blacklist nouveau
cat ./Configs/blacklist-nouveau.conf >/etc/modprobe.d/blacklist-nouveau.conf

# Steam
echo "[multilib]" >>/etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist" >>/etc/pacman.conf
pacman -Sy
pacman -S --noconfirm lib32-fontconfig lib32-libva-mesa-driver lib32-libnm lib32-mesa lib32-mesa-utils lib32-mesa-vdpau lib32-nvidia-utils lib32-systemd steam
su "$paruuser" -P -c 'paru -S --noconfirm proton-ge-custom-bin protonup-qt-bin steamtinkerlaunch && steamtinkerlaunch compat add'

# Setup scanner
echo "$printerip" >> /etc/sane.d/net.conf
brsaneconfig4 -a name=BROTHER-DCP-9020CDW model=DCP-9020CDW ip="$printerip"

# Set user to autologin
sed -i "s/#autologin-user=.*/autologin-user=""$user""/g" /etc/lightdm/lightdm.conf

# Lightdm needs to wait for graphics to load before initialising
sed -i "s/#logind-check-graphical=.*/logind-check-graphical=true/g" /etc/lightdm/lightdm.conf

# Configure QEMU and libvirt
cat ./Configs/qemu.conf >>/etc/libvirt/qemu.conf
sed -i -e "s/\user.*/user\ =\ \"""$user""\"/g" /etc/libvirt/qemu.conf
usermod -a -G libvirt $user
usermod -a -G input $user

mkdir -p /etc/libvirt/{devices,storage,hooks}

# CPU set to performance and GPU preparation via hooks
cat ./Configs/qemu >/etc/libvirt/hooks/qemu
chmod +x /etc/libvirt/hooks/qemu
mkdir -p /etc/libvirt/hooks/qemu.d/win-gaming/prepare/begin/
mkdir -p /etc/libvirt/hooks/qemu.d/win-gaming/release/end/
cat ./Configs/start.sh >/etc/libvirt/hooks/qemu.d/win-gaming/prepare/begin/start.sh
cat ./Configs/end.sh >/etc/libvirt/hooks/qemu.d/win-gaming/release/end/end.sh
chmod -R +x /etc/libvirt/hooks/

# Disable sp5100 watchdog
cat ./Configs/disable-sp5100-watchdog.conf >/etc/modprobe.d/disable-sp5100-watchdog.conf

# Storage options for virt-manager
cat ./Configs/Virtio.xml >/etc/libvirt/storage/Virtio.xml
cat ./Configs/MacOS.xml >/etc/libvirt/storage/MacOS.xml
cat ./Configs/Windows.xml >/etc/libvirt/storage/Windows.xml
ln -s /etc/libvirt/storage/Virtio.xml /etc/libvirt/storage/autostart/Virtio.xml
ln -s /etc/libvirt/storage/MacOS.xml /etc/libvirt/storage/autostart/MacOS.xml
ln -s /etc/libvirt/storage/Windows.xml /etc/libvirt/storage/autostart/Windows.xml

# VM Network
cat ./Configs/default.xml >/etc/libvirt/qemu/networks/default.xml
ln -sf /etc/libvirt/qemu/networks/default.xml /etc/libvirt/qemu/networks/autostart/default.xml

# VM configs
cat ./Configs/macos-high-sierra.xml >/etc/libvirt/qemu/macos.xml
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
cat ./Configs/Ethernet.nmconnection >/etc/NetworkManager/system-connections/Ethernet.nmconnection
sed -i -e "\
  s/\$ipaddress/""$ipaddress""/g; \
  s/\$gateway/""$gateway""/g; \
  s/\$dns/""$dns""/g; \
  s/\$domain/""$domain""/g" \
/etc/NetworkManager/system-connections/Ethernet.nmconnection

cat ./Configs/VirtualBridge.nmconnection >/etc/NetworkManager/system-connections/VirtualBridge.nmconnection.nmconnection
sed -i -e "\
  s/\$dns/""$dns""/g; \
  s/\$domain/""$domain""/g" \
/etc/NetworkManager/system-connections/VirtualBridge.nmconnection.nmconnection

# Create autostart directory if it doesn't exist
mkdir -p /home/"$user"/.config/autostart

# RGB stuff
cat ./Configs/OpenRGB.desktop >/home/"$user"/.config/autostart/OpenRGB.desktop
cat ./Configs/openrgb.sh >/usr/local/bin/openrgb.sh

# Headset Control
cat ./Configs/HeadsetControl.desktop >/home/"$user"/.config/autostart/HeadsetControl.desktop
cat ./Configs/Arctis7PlusChatMix.py >/usr/local/bin/Arctis7PlusChatMix.py
cat ./Configs/99-arctis7plus.rules >/etc/udev/rules.d/99-arctis7plus.rules
sed -i -e "s/\$user/""$user""/g" /etc/udev/rules.d/99-arctis7plus.rules
cat ./Configs/Arctis7PlusChatMix.desktop >/home/"$user"/.config/autostart/Arctis7PlusChatMix.desktop

# Enable backups
cat ./Configs/backup.sh >/usr/local/bin/backup.sh
sed -i -e "s/\$user/""$user""/g" /usr/local/bin/backup.sh
read -n 1 -s -r -p "Switch to another TTY and complete the backup script variables. Press any key to continue..."
cat ./Configs/backup.service >/etc/systemd/system/backup.service
cat ./Configs/backup.timer >/etc/systemd/system/backup.timer

# Configure pipewire to output to all devices
mkdir -p /home/"$user"/.config/pipewire/pipewire-pulse.conf.d
cat ./Configs/add-combined-sink.conf >/home/"$user"/.config/pipewire/pipewire-pulse.conf.d/add-combined-sink.conf
chown colin:colin /home/"$user"/.config/pipewire/pipewire-pulse.conf.d/add-combined-sink.conf

# Shairplay & RPi-play
cat ./Configs/RPi-play.desktop >/home/"$user"/.config/autostart/RPi-play.desktop
cat ./Configs/Shairplay.desktop >/home/"$user"/.config/autostart/Shairplay.desktop
chown "$user":"$user" /home/"$user"/.config/autostart/*

sed -i -e "s/$machine/""$machine""/g" \
  /home/"$user"/.config/autostart/RPi-play.desktop \
  /home/"$user"/.config/autostart/Shairplay.desktop

cat ./Configs/libao.conf >/etc/libao.conf

# Setup monitors in X11
mkdir -p /etc/X11/edid
cp ./Configs/AsusXG32V-edid.txt /etc/X11/edid/
cp ./Configs/ESR-edid.txt /etc/X11/edid/
cat ./Configs/xorg.conf >/etc/X11/xorg.conf

# Set permissions
chmod +x -R \
  /usr/local/bin/*

chown -R "$user":"$user" \
  /home/"$user"/.config/autostart \
  /home/"$user"/.local/state/wireplumber/default-nodes

# Disable initial networking services
systemctl disable systemd-networkd \
                  systemd-resolved

# Enable ALL the services
systemctl enable avahi-daemon \
                 backup.timer \
                 bluetooth \
                 cups \
                 fstrim.timer \
                 haveged \
                 libvirtd \
                 lightdm \
                 NetworkManager \
                 nvidia-persistenced \
                 openrgb \
                 systemd-oomd \
                 systemd-timesyncd \
                 virtlogd.socket \
                 vncserver-x11-serviced

reboot