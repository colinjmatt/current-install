#!/bin/bash
htpcuser="user2" # Name of main user
vnclicense="" # License key for VNC
yayuser="user1" # Name of user that yay (AUR) will be used for

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

pacman -S xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau

(cd /tmp || return
su $yayuser -P -c 'git clone https://aur.archlinux.org/yay.git'
cd /tmp/yay || return
su $yayuser -P -c 'makepkg -si; yay -S realvnc-vnc-server p7zip-gui reflector-timer barrier aacskeys arc-icon-theme-git moka-icon-theme-git faba-icon-theme-git')

vnclicense -add $vnclicense
vncinitconfig -service-daemon

groupadd -r autologin
usermod -a -G autologin htpc
sed -i "s/#autologin-user=.*/autologin-user=""$htpcuser""/g" /etc/lightdm/lightdm.conf

mkdir -p /mnt/Shared
echo "local-shared-01:/NFS/Shared /mnt/Shared nfs vers=4,x-systemd.automount,x-systemd.device-timeout=10,soft,bg" >> /etc/fstab

su -P $htpcuser -c 'mkdir -p /home/htpc/.config/aacs; \
                    wget https://vlc-bluray.whoknowsmy.name/files/KEYDB.cfg -O /home/htpc/.config/aacs/KEYDB.cfg; \
                    flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; \
                    flatpak --user install flathub com.valvesoftware.Steam'

sed -i -e "s/load-module\ module-suspend-on-idle/#load-module module-suspend-on-idle/g" /etc/pulse/default.pa

cat ./HTPCConfigs20-amdgpu.conf >/etc/X11/xorg.conf.d/20-amdgpu.conf

netctl disable ethernet-static
systemctl disable netctl
systemctl enable lightdm NetworkManager vncserver-x11-serviced bluetooth avahi-daemon
reboot
