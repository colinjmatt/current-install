#!/bin/bash
user="user" # Name of main user
auruser="auruser" # Name of user that yay (AUR) will be used for
machine="machine" # Friendly computer name for airplay stuff
domain="local.domain" # Domain this machine will run on
vnclicense="" # License key for VNC
synergyserver="" # Machine that will control this machine via synergy

# Arch key servers are bad
echo "keyserver hkps://keys.openpgp.org" >>/etc/pacman.d/gnupg/gpg.conf

# All currently required software in official repos
pacman -S --noconfirm \
  accountsservice alsa-utils \
  blueman bluez bluez-utils \
  ccache \
  ffmpegthumbnailer file-roller firefox \
  gnome-keyring gst-libav gstreamer-vaapi gtk-engine-murrine gvfs \
  haveged \
  libaacs libbluray libdvdcss libdvdnav libdvdread libgsf libva-mesa-driver libva-utils libva-vdpau-driver libvdpau-va-gl lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
  mesa mesa-vdpau \
  noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra nss-mdns \
  p7zip paprefs pasystray pavucontrol pulseaudio pulseaudio-alsa \
  raw-thumbnailer reflector rsync retroarch retroarch-assets-xmb \
  sshfs \
  ttf-liberation \
  unrar unzip \
  vlc vulkan-radeon \
  xdg-utils xf86-video-amdgpu xfce4 xfce4-goodies xorg-server xorg-xinput xorg-xrandr xterm \
  zip

# Set depth to 10 bit
cat ./Configs/10-bitdepth.conf >/etc/X11/xorg.conf.d/10-bitdepth.conf
sed -i -e "s/\$display/HDMI-A-2/g" /etc/X11/xorg.conf.d/10-bitdepth.conf

# Configure reflector
cat ./Configs/10-mirrorupgrade.hook >/etc/pacman.d/hooks/10-mirrorupgrade.hook

# Set X keymap
localectl set-x11-keymap gb

# Optimise AUR compiles
sed -i "s/BUILDENV=.*/BUILDENV=(fakeroot \!distcc color ccache check \!sign)/g" /etc/makepkg.conf
sed -i "s/#MAKEFLAGS=.*/MAKEFLAGS=\"-j9\"/g" /etc/makepkg.conf

# Install AUR helper of the month (as a non-priviledged user) and install AUR software
( cd /tmp || return
su $auruser -P -c 'git clone https://aur.archlinux.org/paru-bin.git'
cd /tmp/paru || return
su $auruser -P -c 'makepkg -si --noconfirm; \
  paru -S --noconfirm \
  google-chrome \
  p7zip-gui parsec-bin \
  realvnc-vnc-server rpiplay \
  shairplay-git synergy1-bin' )

# Set user to autologin
sed -i "s/#autologin-user=.*/autologin-user=""$user""/g" /etc/lightdm/lightdm.conf

# Lightdm needs to wait for graphics to load (SSD first world issues)
sed -i "s/#logind-check-graphical=.*/logind-check-graphical=true/g" /etc/lightdm/lightdm.conf

# Setup Blu-Ray playback
su -P $user -c "mkdir -p /home/htpc/.config/aacs; \
                    wget http://fvonline-db.bplaced.net/fv_download.php?lang=eng -O /tmp/keydb.cfg.zip; \
                    unzip /tmp/keydb.cfg -d /home/""$user""/.config/aacs/; \
                    mv /home/""$user""/.config/aacs/keydb.cfg /home/""$user""/.config/aacs/KEYDB.cfg; \
                    rm /tmp/keydb.cfg.zip"

# AACS monthly update for Blu Ray playback (for as long as the dependent website is up)
cat ./HTPCConfigs/aacs.service >/etc/systemd/system/aacs.service
cat ./HTPCConfigs/aacs.timer >/etc/systemd/system/aacs.timer
cat ./HTPCConfigs/aacs.sh >/usr/local/bin/aacs.sh
chmod +x /usr/local/bin/aacs.sh

# No delay of sound starting in Pulse
sed -i -e "s/load-module\ module-suspend-on-idle/#load-module\ module-suspend-on-idle/g" /etc/pulse/default.pa /etc/pulse/system.pa

# Set autostarting programs
mkdir -p /home/"$user"/.config/autostart
cat ./HTPCConfigs/Synergy.desktop >/home/"$user"/.config/autostart/Synergy.desktop
cat ./Configs/RPi-play.desktop >/home/"$user"/.config/autostart/RPi-play.desktop
cat ./Configs/Shairplay.desktop >/home/"$user"/.config/autostart/Shairplay.desktop
chown "$user":"$user" /home/"$user"/.config/autostart/*

sed -i -e "s/$machine/""$machine""/g" \
  /home/"$user"/.config/autostart/RPi-play.desktop \
  /home/"$user"/.config/autostart/Shairplay.desktop

sed -i " \
  s/\$synergyserver/""$synergyserver""/g \
  s/\$machine/""$machine""/g \
  s/\$domain/""$domain""/g \
  s/\$user/""$user""/g" \
/home/"$user"/.config/autostart/Synergy.desktop

cat ./Configs/libao.conf >/etc/libao.conf

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
