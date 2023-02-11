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
  accountsservice alsa-plugins alsa-utils \
  barrier blueman bluez bluez-utils \
  ccache \
  ffmpegthumbnailer file-roller firefox fuse2 \
  gnome-keyring gst-libav gstreamer-vaapi gtk-engine-murrine gvfs gvfs-smb \
  haveged helvum \
  libaacs libbluray libdvdcss libdvdnav libdvdread libgsf libopenraw libretro \
  libva-mesa-driver libva-utils libva-vdpau-driver libvdpau-va-gl \
  libxcrypt-compat lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
  mesa mesa-utils mesa-vdpau \
  network-manager-applet networkmanager noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra nss-mdns \
  p7zip paprefs pasystray pavucontrol pipewire pipewire-alsa pipewire-pulse \
  reflector rsync \
  shairplay sshfs \
  ttf-liberation \
  unrar unzip \
  vlc vulkan-radeon \
  wireplumber \
  xdg-utils xf86-video-amdgpu xfce4 xfce4-goodies xorg-server xorg-xinput xorg-xrandr xterm \
  zip

# Steam
echo "[multilib]" >>/etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist" >>/etc/pacman.conf
pacman -Syu --noconfirm
pacman -S lib32-fontconfig lib32-libva-mesa-driver lib32-mesa lib32-mesa-utils lib32-mesa-vdpau lib32-systemd lib32-vulkan-radeon steam --noconfirm
sed -i -e "s/\#en_US.UTF-8\ UTF-8/en_US.UTF-8\ UTF-8/g" /etc/locale.gen
locale-gen

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
cd /tmp/paru-bin || return
su $auruser -P -c 'makepkg -si --noconfirm; \
  paru -S --noconfirm \
  p7zip-gui realvnc-vnc-server rpiplay' )

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

# No delay of sound starting in Pipewire
mkdir -p /etc/wireplumber/main.lua.d/
cp /usr/share/wireplumber/main.lua.d/50-alsa-config.lua /etc/wireplumber/main.lua.d/
sed -i -e "s/--\[\"session.suspend-timeout-seconds\"\].*/\[\"session.suspend-timeout-seconds\"\]\ =\ 0,/g" /etc/wireplumber/main.lua.d/50-alsa-config.lua

# Configure pipewire to output to all devices
cat ./Configs/pactl-combined.desktop >/home/"$user"/.config/autostart/pactl-combined.desktop
cat ./Configs/pactl-combined.sh >/usr/local/bin/pactl-combined.sh
chmod +x /usr/local/bin/pactl-combined.sh

# Configure Barrier (only needed if no SSL certs are preset on the server already)
mkdir -p ~/.local/share/barrier/SSL/Fingerprints
openssl req -x509 -nodes -days 36500 -subj /CN=Barrier -newkey rsa:4096 -keyout ~/.local/share/barrier/SSL/Barrier.pem -out ~/.local/share/barrier/SSL/Barrier.pem
fingerprint=$(openssl x509 -fingerprint -sha256 -noout -in ~/.local/share/barrier/SSL/Barrier.pem | cut -d"=" -f2)
echo "v2:sha256:$fingerprint" > ~/.local/share/barrier/SSL/Fingerprints/TrustedServers.txt

# Set autostarting programs
mkdir -p /home/"$user"/.config/autostart
cat ./HTPCConfigs/Synergy.desktop >/home/"$user"/.config/autostart/Synergy.desktop
cat ./Configs/RPi-play.desktop >/home/"$user"/.config/autostart/RPi-play.desktop
cat ./Configs/Shairplay.desktop >/home/"$user"/.config/autostart/Shairplay.desktop
chown -R "$user":"$user" /home/"$user"/.config/autostart

sed -i -e "s/\$machine/""$machine""/g" \
  /home/"$user"/.config/autostart/RPi-play.desktop \
  /home/"$user"/.config/autostart/Shairplay.desktop

sed -i " \
  s/\$synergyserver/""$synergyserver""/g; \
  s/\$machine/""$machine""/g; \
  s/\$domain/""$domain""/g; \
  s/\$user/""$user""/g" \
/home/"$user"/.config/autostart/Synergy.desktop

cat ./Configs/libao.conf >/etc/libao.conf

# Enable VNC
vnclicense -add "$vnclicense"
vncinitconfig -service-daemon

systemctl disable systemd-networkd

# Enable services
systemctl enable aacs.timer \
                 avahi-daemon \
                 bluetooth \
                 fstrim.timer \
                 haveged \
                 lightdm \
                 NetworkManager \
                 systemd-oomd \
                 systemd-timesyncd \
                 vncserver-x11-serviced

reboot
