#!/bin/bash
htpcuser="htpcuser" # Name of main user
yayuser="yayuser" # Name of user that yay (AUR) will be used for
vnclicense="" # License key for VNC

# All currently required software in official repos
pacman -S xorg-server xorg-xrandr xorg-xinput xdg-utils xterm \
          networkmanager network-manager-applet \
          xfce4 xfce4-goodies lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings gtk-engine-murrine \
          noto-fonts noto-fonts-emoji noto-fonts-extra noto-fonts-cjk ttf-liberation \
          accountsservice slock ffmpegthumbnailer raw-thumbnailer gnome-keyring \
          alsa-utils pulseaudio pulseaudio-alsa pavucontrol pasystray paprefs \
          elementary-icon-theme \
          gvfs \
          p7zip zip unzip unrar file-roller \
          bluez bluez-utils blueman \
          firefox vlc libaacs libdvdcss retroarch retroarch-assets-xmb retroarch-assets-ozone flatpak

# Specifically for AMD graphics
pacman -S xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau
cat ./HTPCConfigs20-amdgpu.conf >/etc/X11/xorg.conf.d/20-amdgpu.conf

# Configure reflector
echo "COUNTRY=UK" >/etc/conf.d/reflector.conf
cat ./Configs/10-mirrorupgrade.hook >/etc/pacman.d/hooks/10-mirrorupgrade.hook

# Set X keymap
localectl set-x11-keymap gb

# Optimise AUR compiles
sed -i "s/BUILDENV=.*/BUILDENV=(fakeroot \!distcc color ccache check \!sign)/g" /etc/makepkg.conf
sed -i "s/#MAKEFLAGS=.*/MAKEFLAGS=\"-j9\"/g" /etc/makepkg.conf

# Install yay (as a non-priviledged user) and install AUR software
( cd /tmp || return
su $yayuser -P -c 'git clone https://aur.archlinux.org/yay.git'
cd /tmp/yay || return
su $yayuser -P -c 'makepkg -si; yay -S realvnc-vnc-server p7zip-gui reflector-timer barrier aacskeys arc-icon-theme-git moka-icon-theme-git faba-icon-theme-git' )

# Set user to autologin
sed -i "s/#autologin-user=.*/autologin-user=""$htpcuser""/g" /etc/lightdm/lightdm.conf

# Setup Blu-Ray playback and Steam
su -P $htpcuser -c 'mkdir -p /home/htpc/.config/aacs;
                    wget https://vlc-bluray.whoknowsmy.name/files/KEYDB.cfg -O /home/htpc/.config/aacs/KEYDB.cfg;
                    flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo;
                    flatpak --user install flathub com.valvesoftware.Steam'

sed -i -e "s/load-module\ module-suspend-on-idle/#load-module module-suspend-on-idle/g" /etc/pulse/default.pa

# Configure Network Manager
cat ./Configs/bridge-master.nmconnection >/etc/NetworkManager/system-connections/Ethernet.nmconnection
sed -i -e "\
  s/\$ipaddress/""$ipaddress""/g; \
  s/\$gateway/""$gateway""/g; \
  s/\$dns/""$dns""/g; \
  s/\$domain/""$domain""/g" \
/etc/NetworkManager/system-connections/Ethernet.nmconnection

# Enable VNC
vnclicense -add "$vnclicense"
vncinitconfig -service-daemon

# Disable initial networking services
systemctl disable systemd-networkd \
                  systemd-resolved

systemctl enable avahi-daemon \
                 bluetooth \
                 lightdm \
                 NetworkManager \
                 vncserver-x11-serviced

reboot