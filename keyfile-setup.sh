#!/bin/bash
clear
lsblk
echo ""
keydrive="$1"
if [[ -z "$keydrive" ]]; then
    echo -n "Please enter the USB drive identifier (eg: sdb) "
    read -r keydrive < /dev/tty
fi

clear
lsblk
echo ""
encrypteddrive="$1"
if [[ -z "$encrypteddrive" ]]; then
    echo -n "Please enter the encrypted drive identifier (eg: sda2) "
    read -r encrypteddrive < /dev/tty
fi

pacman -S --noconfirm parted

mkdir -p /mnt/usbkey
parted -s /dev/"$keydrive" mklabel gpt
mkfs.ext4 /dev/"$keydrive"
mount /dev/"$keydrive" /mnt/usbkey

keydriveUUID=$(blkid /dev/"$keydrive" -o value | head -n1)
dd bs=4096 count=4 if=/dev/urandom of=/mnt/usbkey/crypt.key iflag=fullblock

clear
echo "Encrypted volume password entry"
echo "========================================================================="
echo ""
cryptsetup luksAddKey /dev/"$encrypteddrive" /mnt/usbkey/crypt.key --key-slot 1

# Only needed if the setup in this repo hasn't been used
# sed -i -e "s/MODULES=\"/MODULES=\"nls_cp437 vfat\ /g" /etc/mkinitcpio.conf
# mkinitcpio -P

sed -i -e "s/options\ /options\ cryptkey=UUID=""$keydriveUUID"":ext4:\/crypt.key\ /g" /boot/loader/entries/*.conf

umount /mnt/usbkey
rm -rf /mnt/usbkey
clear
echo "USB encryption keyfile setup!"
