#!/bin/bash
user="user" # single
hostname="hostname" # single
domain="x.local" # single
ipaddress="192.168.0.x" # single
dns="192.168.0.1; 1.1.1.1; 1.0.0.1; 8.8.8.8; 8.8.4.4" # semi-colon separated multiples
gateway="192.168.0.1" # single
printerip="192.168.0.120" # single
vnclicense="" # single
backupuser="backup-user"

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
  discord djvulibre dnsutils dosfstools \
  ebtables edk2-ovmf epdfview exfat-utils \
  ffmpegthumbnailer file-roller firefox firewalld \
  gnome-disk-utility gnome-keyring gscan2pdf gst-libav gstreamer-vaapi gtk-engine-murrine gvfs \
  haveged htop \
  iasl \
  libreoffice-fresh libva-intel-driver libva-utils libva-vdpau-driver libvdpau-va-gl libvirt lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings liquidctl \
  neofetch net-tools network-manager-applet networkmanager networkmanager-openvpn nfs-utils noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra ntfs-3g \
  p7zip paprefs parted pasystray pavucontrol polkit pulseaudio pulseaudio-alsa \
  qemu \
  raw-thumbnailer reflector rsync \
  sane seahorse slock speedtest-cli sshfs \
  tesseract tesseract-data-eng ttf-liberation \
  unrar unzip \
  virt-manager vulkan-intel \
  xdg-utils xfce4 xfce4-goodies xorg-server xorg-xinput xorg-xrandr \
  xterm \
  zip

# Configure reflector
echo "COUNTRY=UK" >/etc/conf.d/reflector.conf
cat ./Configs/10-mirrorupgrade.hook >/etc/pacman.d/hooks/10-mirrorupgrade.hook
cat ./Configs/reflector.service >/etc/systemd/system/reflector.service
cat ./Configs/reflector.timer >/etc/systemd/system/reflector.timer

# Set X keymap
localectl set-x11-keymap gb

# Optimise AUR compiles
sed -i -e "\
  s/BUILDENV=.*/BUILDENV=(fakeroot \!distcc color ccache check \!sign)/g; \
  s/#MAKEFLAGS=.*/MAKEFLAGS=\"-j13\"/g" \
/etc/makepkg.conf

# Install yay (as a non-priviledged user) and install AUR software
pacman -S go --noconfirm
( cd /tmp || return
su $user -P -c 'git clone https://aur.archlinux.org/yay.git'
cd /tmp/yay || return
su $user -P -c 'makepkg -si; \
  gpg
    --keyserver pool.sks-keyservers.net \
    --recv-keys \
      64254695FFF0AA4466CC19E67B96E8162A8CF5D1 \
      5ED9A48FC54C0A22D1D0804CEBC26CDB5A56DE73 \
      E644E2F1D45FA0B2EAA02F33109F098506FF0B14 \
      ABAF11C65A2970B130ABE3C479BE3E4300411886 \
      647F28654894E3BD457199BE38DBBDC86092693E;
  yay -S --noconfirm \
  brother-dcp-9020cdw brscan4 \
  google-chrome gst-plugin-libde265 \
  intel-hybrid-codec-driver \
  keyleds \
  mugshot \
  p7zip-gui parsec-bin \
  realvnc-vnc-server realvnc-vnc-viewer \
  scream speedtest-cli \
  ttf-ms-fonts \
  virtio-win' )

# Change to RT-BFQ kernel on boot
sed -i "s/default\ arch/default\ arch-rt-bfq/g" /boot/loader/loader.conf

# Setup extra partitions
cat ./Configs/crypttab >>/etc/crypttab # A keyfile needs to be generated and placed at /root/.cryptkey for this crypttab to work
cat ./Configs/fstab >> /etc/fstab
mkdir /mnt/{Backup,VMs}
chmod -R 0770 /mnt/{Backup,VMs}
chown root:users /mnt/{Backup,VMs}
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
cat ./Configs/liquidctl.service >/etc/systemd/system/krakenx-config.service
cat ./Configs/liquidctl.sh >/usr/local/bin/liquidctl.sh

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
                 backup.timer \
                 bluetooth \
                 fstrim.timer \
                 haveged \
                 libvirtd \
                 lightdm \
                 liquidctl \
                 NetworkManager \
                 org.cups.cupsd \
                 reflector.timer \
                 vncserver-x11-serviced

reboot
