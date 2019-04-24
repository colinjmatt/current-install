#!/bin/bash
user="" # single
hostname="" # single
domain="" # single
ipaddress="" # single
dns="" # semi colon separated multiples
gateway="" # single
vnclicense="" # single
sshusers="" # multiple
backupuser=""

# All currently required software in official repos
pacman -S \
    xorg-server xorg-xrandr xorg-xinput xdg-utils xterm \
    dnsmasq firewalld ebtables dnsutils bridge-utils \
    networkmanager networkmanager-openvpn network-manager-applet \
    xfce4 xfce4-goodies lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings gtk-engine-murrine \
    accountsservice slock ffmpegthumbnailer raw-thumbnailer gnome-keyring \
    alsa-utils pulseaudio pulseaudio-alsa pavucontrol pasystray paprefs audacity \
    nfs-utils exfat-utils ntfs-3g gvfs sshfs dosfstools parted gnome-disk-utility \
    p7zip zip unzip unrar file-roller \
    elementary-icon-theme arc-icon-theme \
    noto-fonts noto-fonts-emoji noto-fonts-extra noto-fonts-cjk ttf-liberation \
    cups cups-pdf sane djvulibre tesseract tesseract-data-eng \
    firefox epdfview libreoffice-fresh bleachbit \
    qemu libvirt libgsf virt-manager \
    xf86-video-intel vulkan-intel iasl libva-intel-driver gst-libav libvdpau-va-gl \
    rsync ccache speedtest-cli \
    os-prober reflector cpupower haveged

# Install yay (as a non-priviledged user)
cd /tmp || return
git clone https://aur.archlinux.org/yay.git
cd /tmp/yay || return
makepkg -si

# Optimise AUR compiles
sed -i "s/BUILDENV=.*/BUILDENV=(fakeroot \!distcc color ccache check \!sign)/g" /etc/makepkg.conf
sed -i "s/#MAKEFLAGS=.*/MAKEFLAGS=\"-j13\"/g" /etc/makepkg.conf

# All currently required software in AUR
yay -S \
    linux-rt-bfq \
    xfce4-volumed-pulse mugshot \
    p7zip-gui neofetch \
    faba-icon-theme moka-icon-theme \
    ttf-ms-fonts \
    brother-dcp-9020cdw brscan4 gscan2pdf \
    discord realvnc-vnc-server realvnc-vnc-viewer \
    ovmf-git virtio-win dmidecode-git looking-glass-git scream-pulse \
    g810-led-git \
    reflector-timer

# Setup extra local & shared drives
cat ./Configs/crypttab >>/etc/crypttab # A keyfile needs to be generated and placed at /root/.cryptkey for this crypttab to work

mkdir /mnt/{Games,Shared,VMs}

cat ./Configs/fstab >> /etc/fstab
cat ./Configs/nfsd.conf >/etc/modprobe.d/nfsd.conf

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

# Configure QEMU and libvirt
cat ./Configs/qemu.conf >/etc/libvirt/qemu.conf
sed -i -e "s/\$user/""$user""/g" /etc/libvirt/qemu.conf
cat ./Configs/libvirtd.conf >/etc/libvirt/libvirtd.conf
usermod -a -G libvirt $user

# Create service for Looking Glass
cat ./Configs/looking-glass-init.sh >/usr/local/bin/looking-glass-init.sh
sed -i -e "s/\$user/""$user""/g" /usr/local/bin/looking-glass-init.sh
cat ./Configs/looking-glass-init.service >/etc/systemd/system/looking-glass-init.service

# Create SSL keys for Spice
mkdir /etc/pki
mkdir /etc/pki/qemu
cd /etc/pki/qemu || return
openssl genrsa -des3 -out ca-key.pem 1024
openssl req -new -x509 -days 750 -key ca-key.pem -out ca-cert.pem -utf8 -subj "/CN=Self Signed"
openssl genrsa -out server-key.pem 1024
openssl req -new -key server-key.pem -out server-key.csr -utf8 -subj "/CN=$user"
openssl x509 -req -days 750 -in server-key.csr -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out server-cert.pem
openssl rsa -in server-key.pem -out server-key.pem.insecure
mv server-key.pem server-key.pem.secure
mv server-key.pem.insecure server-key.pem
sudo chown root:kvm ./*
sudo chmod 0440 ./*

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
    s/\$hostname/""$hostname""/g \
    s/\$enet/""$enet""/g" \
/etc/NetworkManager/system-connections/Bridge\ Slave\ "$hostname".nmconnection

# Configure dnsmasq & enable for Network Manager
cat ./Configs/dnsmasq.conf >/etc/dnsmasq.conf
sed -i -e "s/\$ipaddress/""$ipaddress""/g" /etc/dnsmasq.conf
IFS=\;
for server in $dns; do
    echo server=$server >> /etc/dnsmasq.conf
done
echo -e "[main]\ndns=dnsmasq" >/etc/NetworkManager/NetworkManager.conf

# Libvirt hook to call cpupower and set governor to performance
mkdir /etc/libvirt/hooks
cat ./Configs/qemu >/etc/libvirt/hooks/qemu
chmod +x /etc/libvirt/hooks/qemu

# Add domain to idmapd.conf
sed -i -e "s/#Domain\ =/Domain\ =\ ""$domain""/g" /etc/idmapd.conf

# Fix system freezes when copying lots of/huge files
cat ./Configs/10-copying.conf >/etc/sysctl.d/10-copying.conf

# G810 Keyboard LED theme
cat ./Configs/g810-led-profile >/etc/g810-led/profile

# Install VNC
vnclicense -add $vnclicense
vncinitconfig -service-daemon

# Enable attached pi_shutdown when machine shuts down
cat ./Configs/pi_shutdown.sh >/usr/local/bin/pi_shutdown.sh
cat ./Configs/pi_shutdown.service >/etc/systemd/system/pi_shutdown.service

# Enable rsync backup
cat ./Configs/backup.sh >/usr/local/bin/backup.sh
sed -i -e "s/\$backupuser/""$backupuser""/g" /usr/local/bin/backup.sh
cat ./Configs/rsync_backup.service >/etc/systemd/system/rsync_backup.service
cat ./Configs/rsync_backup.timer >/etc/systemd/system/rsync_backup.timer

# Everything in /usr/local/bin is executable
chmod +x -R /usr/local/bin/*

# Enable ALL the services
systemctl enable    avahi-daemon \
                    dnsmasq \
                    haveged \
                    libvirtd \
                    lightdm \
                    looking-glass-init \
                    NetworkManager \
                    org.cups.cupsd \
                    pi_shutdown \
                    reflector.timer \
                    rsync_backup.timer \
                    shareddrives \
                    vncserver-x11-serviced

# Disable initial networking and reboot
netctl disable ethernet-dhcp
systemctl disable netctl
reboot
