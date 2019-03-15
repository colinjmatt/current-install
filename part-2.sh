$hostname#!/bin/bash
user=""
hostname=""
sharedpassword=""
vpnpassword=""
vnclicense=""
shareduser=""
sharedpass=""
ipaddress=""
sshusers=""

# All currently required software in official repos
pacman -S \
    xorg-server xf86-video-intel xorg-xrandr xorg-xinput xdg-utils xterm \
    dnsmasq firewalld ebtables dnsutils bridge-utils \
    networkmanager networkmanager-openvpn network-manager-applet \
    xfce4 xfce4-goodies lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings gtk-engine-murrine \
    accountsservice slock ffmpegthumbnailer raw-thumbnailer libsecret gnome-keyring \
    alsa-utils pulseaudio pulseaudio-alsa pavucontrol pasystray paprefs \
    nfs-utils exfat-utils ntfs-3g gvfs gvfs-smb sshfs dosfstools parted gnome-disk-utility \
    p7zip zip unzip unrar file-roller \
    elementary-icon-theme arc-icon-theme \
    noto-fonts noto-fonts-emoji noto-fonts-extra noto-fonts-cjk ttf-liberation \
    cups cups-pdf sane djvulibre tesseract tesseract-data-eng \
    firefox epdfview libreoffice-fresh bleachbit \
    qemu libvirt libgsfvirt-manager \
    vulkan-intel iasl libva-intel-driver gst-libav libvdpau-va-gl \
    git ccache \
    os-prober reflector cpupower haveged

# Enable ssh to assist with rest of setup
systemctl enable sshd
systemctl start sshd

# Install yay
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

# All currently required software in AUR
yay -S \
    linux-rt-bfq \
    xfce4-volumed-pulse mugshot \
    p7zip-gui neofetch \
    faba-icon-theme moka-icon-theme \
    ttf-ms-fonts \
    brother-dcp-9020cdw brscan4 gscan2pdf \
    discord darkaudacity-git realvnc-vnc-server realvnc-vnc-viewer grub-customizer \
    ovmf-git virtio-win dmidecode-git looking-glass-git scream-pulse \
    g810-led-git \
    reflector-timer

# Setup extra local & shared drives
cat ./Configs/crypttab >>/etc/crypttab # A keyfile needs to be generated or placed at /root/.cryptkey

mkdir /mnt/{Backup,Downloads,FTP,Games,Media,Vault,VMs,Store}
chmod 0777 /mnt/{Backup,Downloads,FTP,Media,Vault,Store}
chown root:users /mnt/{Backup,Downloads,FTP,Media,Store}

cat ./Configs/fstab >> /etc/fstab
cat ./Configs/shareddrives.service /etc/systemd/system/shareddrives.service
chmod +x /usr/local/bin/shareddrives.sh

echo "username=$shareduser" >/root/.sharedcredentials
echo "password=$sharedpass" >>/root/.sharedcredentials

# Stop screen tearing
cat ./Configs/20-intel.conf >/etc/X11/xorg.conf.d/20-intel.conf

# Configure reflector
mkdir /etc/pacman.d/hooks
cat ./Configs/10-mirrorupgrade.hook >/etc/pacman.d/hooks/10-mirrorupgrade.hook

# Create Reflector service that runs every startup
cat ./Configs/reflector.service >/etc/systemd/system/reflector.service
cat ./Configs/reflector.timer >/etc/systemd/system/reflector.timer

# Set country for reflector
echo "COUNTRY=UK" > /etc/conf.d/reflector.conf

# Setup scanner
echo "192.168.0.120" >> /etc/sane.d/net.conf
brsaneconfig4 -a name=BROTHER-DCP-9020CDW model=DCP-9020CDW ip=192.168.0.120

# Set user to autologin
sed -i "s/#autologin-user=.*/autologin-user=""$user""/g" /etc/lightdm/lightdm.conf

# Optimise AUR compiles
sed -i "s/BUILDENV=.*/BUILDENV=(fakeroot \!distcc color ccache check \!sign)/g" /etc/makepkg.conf
sed -i "s/#MAKEFLAGS=.*/MAKEFLAGS=\"-j13\"/g" /etc/makepkg.conf

# Configure QEMU and libvirt
cat ./Configs/qemu.conf >/etc/libvirt/qemu.conf
sed -i -e "s/\$user/""$user""/g" /etc/libvirt/qemu.conf
cat ./Configs/libvirtd.conf >/etc/libvirt/libvirtd.conf
sed -i -e "s/\$user/""$user""/g" /etc/libvirt/libvirtd.conf

usermod -a -G libvirt $user

# Create service for Looking Glass
cat ./Configs/looking-glass-init.sh >/usr/local/bin/looking-glass-init.sh
sed -i -e "s/\$user/""$user""/g" /usr/local/bin/looking-glass-init.sh
chmod +x /usr/local/bin/looking-glass-init.sh
cat ./Configs/looking-glass-init.service >/etc/systemd/system/looking-glass-init.service

# Create SSL keys for Spice
mkdir /etc/pki
mkdir /etc/pki/qemu
cd /etc/pki/qemu
openssl genrsa -des3 -out ca-key.pem 1024
openssl req -new -x509 -days 750 -key ca-key.pem -out ca-cert.pem -utf8 -subj "/CN=Self Signed"
openssl genrsa -out server-key.pem 1024
openssl req -new -key server-key.pem -out server-key.csr -utf8 -subj "/CN=colin"
openssl x509 -req -days 750 -in server-key.csr -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out server-cert.pem
openssl rsa -in server-key.pem -out server-key.pem.insecure
mv server-key.pem server-key.pem.secure
mv server-key.pem.insecure server-key.pem
sudo chown root:kvm ./*
sudo chmod 0440 ./*

# Configure Network Manager
cat ./Configs/network-bridge-master >/etc/NetworkManager/system-connections/Bridge\ $hostname
sed -i -e "s/\$hostname/""$hostname""/g" /etc/NetworkManager/system-connections/Bridge\ $hostname

cat ./Configs/network-bridge-slave >/etc/NetworkManager/system-connections/Bridge\ Slave\ $hostname
enet=$(ls /sys/class/net/ | grep "^en")
sed -i -e "s/\$enet/""$enet""/g" /etc/NetworkManager/system-connections/Bridge\ Slave\ $hostname

cat ./Configs/vpn >/etc/NetworkManager/system-connections/IVPN\ United\ Kingdom
sed -i -e "s/\$user/""$user""/g" /etc/NetworkManager/system-connections/IVPN\ United\ Kingdom
sed -i -e "s/\$vpnpassword/""$vpnpassword""/g" /etc/NetworkManager/system-connections/IVPN\ United\ Kingdom

# Configure dnsmasq
cat ./Configs/dnsmasq.conf >/etc/dnsmasq.conf
sed -i -e "s/\$ipaddress/""$ipaddress""/g"

# Enable dnsmasq for Network Manager
echo "dns=dnsmasq" /etc/NetworkManager/NetworkManager.conf

# Configure SSH
cat ./Configs/sshd_config >/etc/ssh/sshd_config
sed -i -e "s/\$sshusers/""$sshusers""/g"

# Libvirt hook to call cpupower and set governor to performance
mkdir /etc/libvirt/hooks
cat ./Configs/qemu >/etc/libvirt/hooks/qemu
chmod +x /etc/libvirt/hooks/qemu

# Fix system freezes when copying lots of/huge files
cat ./Configs/10-copying.conf >/etc/sysctl.d/10-copying.conf

# G810 Keyboard LED theme
cat ./Configs/g810-led-profile >/etc/g810-led/profile

# Install VNC
vnclicense -add $vnclicense
vncinitconfig -service-daemon

# Set locale
localectl set-keymap uk
localectl set-x11-keymap uk
localectl set-locale LANG="en_GB.UTF-8"

# Set time synchronisation
timedatectl set-ntp true

# Enable ALL the services
systemctl enable    avahi-daemon \
                    haveged \
                    libvirtd \
                    lightdm \
                    looking-glass-init \
                    NetworkManager \
                    org.cups.cupsd \
                    reflector.timer \
                    shareddrives \
                    vncserver-x11-serviced

# Disable initial networking and reboot
netctl disable enet-dhcp
systemctl disable netctl
reboot
