#!/bin/bash

clear
lsblk
echo ""
keydrive="$1"
if [[ -z "$keydrive" ]]; then
    echo -n "Please enter the USB drive identifier (eg: sdb) "
    read -r USB < /dev/tty
fi

clear
lsblk
echo ""
encrypteddrive="$1"
if [[ -z "$encrypteddrive" ]]; then
    echo -n "Please enter the encrypted drive identifier (eg: sda2) "
    read -r CRYPT < /dev/tty
fi

sudo pacman -S --noconfirm dosfstools parted

sudo mkdir -p /mnt/usbkey
sudo parted -s /dev/"$keydrive" mklabel gpt
sudo parted -s /dev/"$keydrive" mkpart FAT32
sudo mkfs.vfat -I /dev/"$keydrive"
sudo mount /dev/"$keydrive" /mnt/usbkey

keydriveUUID=$(blkid /dev/""$keydrive"" -o value | sed -n "/msdos/{n;p}")
sudo dd bs=1024 count=4 if=/dev/urandom of=/mnt/usbkey/crypt.key iflag=fullblock

clear
echo "Encrypted volume password entry"
echo "========================================================================="
echo ""
sudo cryptsetup luksAddKey /dev/"$encrypteddrive" /mnt/usbkey/crypt.key --key-slot 1

sudo sed -i -e "s/MODULES=\"/MODULES=\"nls_cp437 vfat\ /g" /etc/mkinitcpio.conf
mkinitcpio -p linux linux-rt-bfq

sudo sed -i -e "s/options\ /options\ cryptkey=UUID=""$keydriveuuid"":vfat:\/crypt.key\ /g" /boot/loader/entries/*.conf

sudo umount /mnt/usbkey
sudo rm -rf /mnt/usbkey
clear
echo "USB encryption keyfile setup!"
