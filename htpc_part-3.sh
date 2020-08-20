#!/bin/bash
htpcuser="htpcuser" # Name of main user
yayuser="yayuser" # Name of user that yay (AUR) will be used for
vnclicense="" # License key for VNC

# All currently required software in official repos
pacman -S xorg-server xorg-xrandr xorg-xinput xdg-utils xterm \
          xfce4 xfce4-goodies lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings gtk-engine-murrine \
          noto-fonts noto-fonts-emoji noto-fonts-extra noto-fonts-cjk ttf-liberation \
          accountsservice slock ffmpegthumbnailer raw-thumbnailer gnome-keyring \
          alsa-utils pulseaudio pulseaudio-alsa pavucontrol pasystray paprefs \
          elementary-icon-theme \
          gvfs \
          p7zip zip unzip unrar file-roller \
          bluez bluez-utils blueman \
          ccache rsync haveged barrier \
          firefox vlc libbluray libaacs libdvdcss libdvdread libdvdnav reflector

# Specifically for AMD graphics
pacman -S xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau
cat ./HTPCConfigs/20-amdgpu.conf >/etc/X11/xorg.conf.d/20-amdgpu.conf

# Configure reflector
echo "COUNTRY=UK" >/etc/conf.d/reflector.conf
cat ./Configs/10-mirrorupgrade.hook >/etc/pacman.d/hooks/10-mirrorupgrade.hook
cat ./Configs/reflector.service >/etc/systemd/system/reflector.service
cat ./Configs/reflector.timer >/etc/systemd/system/reflector.timer

# Set X keymap
localectl set-x11-keymap gb

# Optimise AUR compiles
sed -i "s/BUILDENV=.*/BUILDENV=(fakeroot \!distcc color ccache check \!sign)/g" /etc/makepkg.conf
sed -i "s/#MAKEFLAGS=.*/MAKEFLAGS=\"-j9\"/g" /etc/makepkg.conf

# Install yay (as a non-priviledged user) and install AUR software
( cd /tmp || return
su $yayuser -P -c 'git clone https://aur.archlinux.org/yay.git'
cd /tmp/yay || return
su $yayuser -P -c 'makepkg -si; \
                   yay -S \
                   parsec-bin realvnc-vnc-server google-chrome p7zip-gui \
                   arc-icon-theme-git moka-icon-theme-git faba-icon-theme-git' )

# Set user to autologin
sed -i "s/#autologin-user=.*/autologin-user=""$htpcuser""/g" /etc/lightdm/lightdm.conf

# Setup Blu-Ray playback and Steam
su -P $htpcuser -c "mkdir -p /home/htpc/.config/aacs; \
                    wget http://fvonline-db.bplaced.net/fv_download.php?lang=eng -O /tmp/keydb.cfg.zip; \
                    unzip /tmp/keydb.cfg -d /home/""$htpcuser""/.config/aacs/; \
                    mv /home/""$htpcuser""/.config/aacs/keydb.cfg /home/""$htpcuser""/.config/aacs/KEYDB.cfg; \
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
                 reflector.timer \
                 vncserver-x11-serviced

reboot
