#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e 

echo "Starting Raspberry Pi 4 Provisioning..."

# ==========================================
# 0. VARIABLES (Set these before running)
# ==========================================
WIFI_SSID="YOUR_SSID"
WIFI_PASS="YOUR_WIFI_PASSWORD"
WLAN_STATIC_IP="192.168.1.100/24"
WLAN_GATEWAY="192.168.1.1"
DNS_SERVER="192.168.1.1"
HOSTNAME="alarm"

# ==========================================
# 1. BASE SYSTEM (Time, Locale, Hostname)
# ==========================================
echo "Configuring base system..."

echo "$HOSTNAME" > /etc/hostname

# Set UK Timezone
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc

# Generate Locales
sed -i 's/^#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

# ==========================================
# 2. NETWORKING (wpa_supplicant & networkd)
# ==========================================
echo "Configuring network..."

# wpa_supplicant configuration
cat <<EOF > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel
update_config=1
country=GB

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASS"
}
EOF
chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan0.conf

# systemd-networkd: wlan0 (Static IP)
cat <<EOF > /etc/systemd/network/20-wlan0.network
[Match]
Name=wlan0

[Network]
Address=$WLAN_STATIC_IP
Gateway=$WLAN_GATEWAY
DNS=$DNS_SERVER
EOF

# Enable networking services
systemctl enable wpa_supplicant@wlan0.service
systemctl enable systemd-networkd.service

# ==========================================
# 3. PACKAGES & DEPENDENCIES
# ==========================================
echo "Installing base packages..."
pacman -Syu --noconfirm base-devel docker git python-pip sudo swig

# ==========================================
# 4. SSH HARDENING
# ==========================================
echo "Securing SSH..."
CONFIG="/etc/ssh/sshd_config"

sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$CONFIG"
sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' "$CONFIG"
sed -i 's/^HostKey.*rsa_key/#&/' "$CONFIG"
sed -i 's/^HostKey.*ecdsa_key/#&/' "$CONFIG"
sed -i 's/^#*HostKey.*ed25519_key/HostKey \/etc\/ssh\/ssh_host_ed25519_key/' "$CONFIG"
sed -i '/^PubkeyAcceptedAlgorithms/d' "$CONFIG"
sed -i '/^HostKeyAlgorithms/d' "$CONFIG"
sed -i '$ a PubkeyAcceptedAlgorithms ssh-ed25519' "$CONFIG"
sed -i '$ a HostKeyAlgorithms ssh-ed25519' "$CONFIG"

# Enable sshd service
systemctl enable sshd.service

# ==========================================
# 5. USERS & PROFILES
# ==========================================
echo "Configuring users..."
cat ./Configs/root_bashrc >/root/.bashrc
cat ./Configs/user_bashrc >/etc/skel/.bashrc
cat ./Configs/root_nanorc >/root/.nanorc
cat ./Configs/user_nanorc >/etc/skel/.nanorc
cat ./Configs/nanorc >/etc/nanorc

usermod -aG docker,wheel alarm
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo "alarm ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/10-pacman
chmod 440 /etc/sudoers.d/10-pacman

# ==========================================
# 6. CUSTOM BUILDS (paru, lgpio, argononed)
# ==========================================
echo "Compiling AUR packages and C-libraries..."

sudo -u alarm bash -c '
    cd /tmp
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
'

sudo -u alarm bash -c '
    cd /tmp
    curl -LO https://github.com/joan2937/lg/archive/refs/heads/master.tar.gz
    tar -xzf master.tar.gz
    cd lg-master
    make
'
cd /tmp/lg-master
make install
cp liblgpio.so* /usr/lib/
cp lgpio.h /usr/include/
ldconfig

pip install rpi-lgpio --break-system-packages

sudo -u alarm bash -c '
    cd /tmp
    git clone https://github.com/colinjmatt/argononed.git
    cd argononed
    makepkg -si --noconfirm
'
systemctl enable argononed.service

# ==========================================
# 7. WI-FI WATCHDOG (Systemd Timer)
# ==========================================
echo "Installing Wi-Fi Watchdog..."

# Create the executable bash script
# (Notice EOF is NOT quoted, allowing us to inject $WLAN_GATEWAY directly)
cat << EOF > /usr/local/bin/wifi-watchdog.sh
#!/bin/bash
if ! ping -c 2 -W 5 "$WLAN_GATEWAY" > /dev/null 2>&1; then
    logger "WiFi Watchdog: Network unreachable. Restarting wpa_supplicant..."
    systemctl restart wpa_supplicant@wlan0.service
    sleep 5
    systemctl restart systemd-networkd.service
fi
EOF
chmod +x /usr/local/bin/wifi-watchdog.sh

# Create the Systemd Service
cat << 'EOF' > /etc/systemd/system/wifi-watchdog.service
[Unit]
Description=WiFi Watchdog Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wifi-watchdog.sh
EOF

# Create the Systemd Timer (runs every 5 minutes)
cat << 'EOF' > /etc/systemd/system/wifi-watchdog.timer
[Unit]
Description=Run WiFi Watchdog every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

# Enable the timer (not the service!)
systemctl enable wifi-watchdog.timer

# ==========================================
# 8. FINAL HARDWARE CONFIG
# ==========================================
echo "Configuring hardware interfaces..."
echo "dtparam=i2c_arm=on" >> /boot/config.txt
echo "i2c-dev" > /etc/modules-load.d/i2c-dev.conf

systemctl enable docker.service

echo "Provisioning complete. Rebooting in 5 seconds..."
sleep 5
reboot