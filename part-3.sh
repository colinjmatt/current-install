#!/bin/bash
user="user" # single user only
machine="machine" # Friendly computer name for airplay stuff
domain="x.local"
ipaddress="192.168.1.x"
dns="192.168.1.1; 1.1.1.1; 1.0.0.1; 8.8.8.8; 8.8.4.4" # semi-colon separated multiples
gateway="192.168.1.1"
printerip="192.168.1.120"
vnclicense=""

dns2="${dns//;}"

# Add DNS server(s)
for server in $dns2; do
  echo "nameserver $server" >> /etc/resolv.conf
done

# Arch key servers are bad
echo "keyserver hkps://keys.openpgp.org" >>/etc/pacman.d/gnupg/gpg.conf

# All currently required software in official repos
pacman -S --noconfirm \
  accountsservice alsa-utils audacity \
  bleachbit blueman bluez bluez-utils bridge-utils \
  ccache cpupower cups cups-pdf \
  discord djvulibre dmidecode dnsmasq dnsutils dosfstools \
  ebtables edk2-ovmf epdfview exfat-utils \
  ffmpegthumbnailer file-roller firefox firewalld \
  gnome-disk-utility gnome-keyring gscan2pdf gst-libav gstreamer-vaapi gtk-engine-murrine gvfs \
  haveged htop \
  i2c-tools iasl \
  libgsf libreoffice-fresh libva-intel-driver libva-utils libva-vdpau-driver libvdpau-va-gl \
  libvirt lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings linux-headers liquidctl \
  neofetch net-tools network-manager-applet networkmanager networkmanager-openvpn nfs-utils \
  noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra nss-mdns ntfs-3g \
  p7zip paprefs parted pasystray pavucontrol polkit pulseaudio pulseaudio-alsa \
  qemu \
  raw-thumbnailer reflector rsync \
  sane seahorse slock speedtest-cli sshfs \
  tesseract tesseract-data-eng ttf-liberation \
  unrar unzip usbutils \
  virt-manager vulkan-intel \
  xdg-utils xf86-video-intel xfce4 xfce4-goodies xorg-server xorg-xinput xorg-xrandr xterm \
  zip

# Set depth to 10 bit (current panel is 8 bit)
# cat ./Configs/10-bitdepth.conf >/etc/X11/xorg.conf.d/10-bitdepth.conf
# sed -i -e "s/\$display/DP1/g" /etc/X11/xorg.conf.d/10-bitdepth.conf

# Configure reflector
cat ./Configs/10-mirrorupgrade.hook >/etc/pacman.d/hooks/10-mirrorupgrade.hook

# Set X keymap
localectl set-x11-keymap gb

# Optimise AUR compiles
sed -i -e "\
  s/BUILDENV=.*/BUILDENV=(fakeroot \!distcc color ccache check \!sign)/g; \
  s/#MAKEFLAGS=.*/MAKEFLAGS=\"-j13\"/g" \
/etc/makepkg.conf

# Install AUR helper of the month (as a non-priviledged user) and install AUR software
( cd /tmp || return
su $yayuser -P -c 'git clone https://aur.archlinux.org/paru-bin.git'
cd /tmp/paru || return
su $yayuser -P -c 'makepkg -si --noconfirm; \
  paru -S --noconfirm \
  brother-dcp-9020cdw brscan4 \
  google-chrome \
  i2c-nct6775-dkms \
  keyleds \
  mugshot \
  openrgb-bin \
  p7zip-gui parsec-bin \
  realvnc-vnc-server realvnc-vnc-viewer rpiplay \
  scream shairplay-git \
  ttf-ms-fonts \
  virtio-win \
  xfce4-volumed-pulse-git')

# Setup extra partitions
mkdir /mnt/backup
chmod -R 0770 /mnt/{backup,VMs}
chown -R root:users /mnt/{backup,VMs}

# Setup scanner
echo "$printerip" >> /etc/sane.d/net.conf
brsaneconfig4 -a name=BROTHER-DCP-9020CDW model=DCP-9020CDW ip="$printerip"

# Set user to autologin
sed -i "s/#autologin-user=.*/autologin-user=""$user""/g" /etc/lightdm/lightdm.conf

# Lightdm needs to wait for graphics to load (SSD first world issues)
sed -i "s/#logind-check-graphical=.*/logind-check-graphical=true/g" /etc/lightdm/lightdm.conf

# Configure QEMU and libvirt
cat ./Configs/attach.sh >/usr/local/bin/attach.sh
cat ./Configs/qemu.conf >>/etc/libvirt/qemu.conf
sed -i -e "s/\user.*/user\ =\ \"""$user""\"/g" /etc/libvirt/qemu.conf
usermod -a -G libvirt $user
usermod -a -G input $user

mkdir -p /etc/libvirt/{devices,storage,hooks}
mkdir /etc/libvirt/storage/autostart

# Devices to pass to the gaming VM
cat ./Configs/logi_keyb.xml >/etc/libvirt/devices/logi_keyb.xml
cat ./Configs/logi_mouse.xml >/etc/libvirt/devices/logi_mouse.xml

# Set governor to performance when gaming VM is running to reduce latency
cat ./Configs/qemu >/etc/libvirt/hooks/qemu
chmod +x /etc/libvirt/hooks/qemu

# Storage options for virt-manager
cat ./Configs/default.xml >/etc/libvirt/storage/default.xml
cat ./Configs/Virtio.xml >/etc/libvirt/storage/Virtio.xml
ln -s /etc/libvirt/storage/default.xml /etc/libvirt/storage/autostart/default.xml
ln -s /etc/libvirt/storage/Virtio.xml /etc/libvirt/storage/autostart/Virtio.xml

# VM configs
cat ./Configs/default.xml >/etc/libvirt/qemu/win10-gaming.xml
cat ./Configs/default.xml >/etc/libvirt/qemu/win10-work.xml

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
cat ./Configs/Bridge\ Master-c8747370-fba6-4f74-a42e-583d630758ee.nmconnection >/etc/NetworkManager/system-connections/Bridge\ Master-c8747370-fba6-4f74-a42e-583d630758ee.nmconnection
sed -i -e "\
  s/\$domain/""$domain""/g; \
  s/\$ipaddress/""$ipaddress""/g; \
  s/\$dns/""$dns""/g; \
  s/\$gateway/""$gateway""/g" \
/etc/NetworkManager/system-connections/Bridge\ Master.nmconnection

cat ./Configs/Bridge\ Slave.nmconnection >/etc/NetworkManager/system-connections/Bridge\ Slave.nmconnection
enet=$(ls /sys/class/net/ | grep "^en")
sed -i -e "s/\$enet/""$enet""/g" /etc/NetworkManager/system-connections/Bridge\ Slave.nmconnection

# RGB stuff
cat ./Configs/openrgb.sh >/usr/local/bin/openrgb.sh
cat ./Configs/openrgb.service >/etc/systemd/system/openrgb.service

cat ./Configs/liquidctl.service >/etc/systemd/system/liquidctl.service
cat ./Configs/liquidctl.sh >/usr/local/bin/liquidctl.sh

mkdir -p /home/"$user"/.config/keyleds
cat ./Configs/keyleds.yml >/home/"$user"/.config/keyleds/keyleds.yml

mkdir -p /home/"$user"/.config/autostart
cat ./Configs/Keyleds.desktop >/home/"$user"/.config/autostart/Keyleds.desktop
cat ./Configs/OpenRGB.desktop >/home/"$user"/.config/autostart/OpenRGB.desktop

# Enable VNC
vnclicense -add "$vnclicense"
vncinitconfig -service-daemon

# Enable backups
cat ./Configs/backup.sh >/usr/local/bin/backup.sh
read -n 1 -s -r -p "Switch to another TTY and complete the backup script variables. Press any key to continue..."
cat ./Configs/backup.service >/etc/systemd/system/backup.service
cat ./Configs/backup.timer >/etc/systemd/system/backup.timer

# Add scream listener to autostart
cat ./Configs/PulseAudio\ Scream\ Listener.desktop >/home/"$user"/.config/autostart/PulseAudio\ Scream\ Listener.desktop

# Shairplay & RPi-play
mkdir -p /home/"$user"/.config/autostart
cat ./Configs/RPi-play.desktop >/home/"$user"/.config/autostart/RPi-play.desktop
cat ./Configs/Shairplay.desktop >/home/"$user"/.config/autostart/Shairplay.desktop
chown "$user":"$user" /home/"$user"/.config/autostart/*

sed -i -e "s/$machine/""$machine""/g" \
  /home/"$user"/.config/autostart/RPi-play.desktop \
  /home/"$user"/.config/autostart/Shairplay.desktop

cat ./Configs/libao.conf >/etc/libao.conf

# Set permissions
chmod +x -R \
  /usr/local/bin/*
chown -R "$user":"$user" \
  /home/"$user"/.config/keyleds/ \
  /home/"$user"/.config/autostart

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
                 liquidctl \
                 NetworkManager \
                 openrgb \
                 virtlogd.socket \
                 vncserver-x11-serviced

reboot
