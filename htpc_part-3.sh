#!/bin/bash
user="user" # Name of main user
yayuser="yayuser" # Name of user that yay (AUR) will be used for
vnclicense="" # License key for VNC

# Arch key servers are bad
echo "keyserver hkps://keys.openpgp.org" >>/etc/pacman.d/gnupg/gpg.conf

# All currently required software in official repos
pacman -S --noconfirm \
  accountsservice alsa-utils \
  barrier blueman bluez bluez-utils \
  ccache \
  ffmpegthumbnailer file-roller firefox \
  gnome-keyring gst-libav gstreamer-vaapi gtk-engine-murrine gvfs \
  haveged \
  libaacs libbluray libdvdcss libdvdnav libdvdread libva-utils libva-vdpau-driver libvdpau-va-gl lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
  noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra \
  p7zip paprefs pasystray pavucontrol pulseaudio pulseaudio-alsa \
  raw-thumbnailer reflector rsync retroarch retroarch-assets-xmb \
  ttf-liberation \
  unrar unzip \
  vlc \
  xdg-utils xfce4 xfce4-goodies xorg-server xorg-xinput xorg-xrandr xterm \
  zip

# Specifically for AMD graphics
pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau
cat ./HTPCConfigs/20-amdgpu.conf >/etc/X11/xorg.conf.d/20-amdgpu.conf

# Configure reflector
cat ./Configs/10-mirrorupgrade.hook >/etc/pacman.d/hooks/10-mirrorupgrade.hook

# Set X keymap
localectl set-x11-keymap gb

# Optimise AUR compiles
sed -i "s/BUILDENV=.*/BUILDENV=(fakeroot \!distcc color ccache check \!sign)/g" /etc/makepkg.conf
sed -i "s/#MAKEFLAGS=.*/MAKEFLAGS=\"-j9\"/g" /etc/makepkg.conf

# Install yay (as a non-priviledged user) and install AUR software
( cd /tmp || return
pacman -S --noconfirm go
su $yayuser -P -c 'git clone https://aur.archlinux.org/yay.git'
cd /tmp/yay || return
su $yayuser -P -c 'makepkg -si; \
  yay -S --noconfirm \
  google-chrome \
  p7zip-gui \
  parsec-bin \
  realvnc-vnc-server \
  rpiplay' )

# Set user to autologin
sed -i "s/#autologin-user=.*/autologin-user=""$user""/g" /etc/lightdm/lightdm.conf

# Setup Blu-Ray playback and Steam
su -P $user -c "mkdir -p /home/htpc/.config/aacs; \
                    wget http://fvonline-db.bplaced.net/fv_download.php?lang=eng -O /tmp/keydb.cfg.zip; \
                    unzip /tmp/keydb.cfg -d /home/""$user""/.config/aacs/; \
                    mv /home/""$user""/.config/aacs/keydb.cfg /home/""$user""/.config/aacs/KEYDB.cfg; \
                    rm /tmp/keydb.cfg.zip"

sed -i -e "s/load-module\ module-suspend-on-idle/#load-module module-suspend-on-idle/g" /etc/pulse/default.pa

# AACS monthly update for Blu Ray playback (for as long as the dependent website is up)
cat ./HTPCConfigs/aacs.service >/etc/systemd/system/aacs.service
cat ./HTPCConfigs/aacs.timer >/etc/systemd/system/aacs.timer
cat ./HTPCConfigs/aacs.sh >/usr/local/bin/aacs.sh
chmod +x /usr/local/bin/aacs.sh

# Enable VNC
vnclicense -add "$vnclicense"
vncinitconfig -service-daemon

# Enable services
systemctl enable aacs.timer \
                 avahi-daemon \
                 bluetooth \
                 fstrim.timer \
                 haveged \
                 lightdm \
                 vncserver-x11-serviced

reboot
