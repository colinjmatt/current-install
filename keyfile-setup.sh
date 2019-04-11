#!/bin/bash

clear
lsblk
echo ""
KEYDRIVE="$1"
if [[ -z "$KEYDRIVE" ]]; then
    echo -n "Please enter the USB drive identifier (eg: sdb) "
    read -r USB < /dev/tty
fi

clear
lsblk
echo ""
ENCRYPTEDDRIVE="$1"
if [[ -z "$ENCRYPTEDDRIVE" ]]; then
    echo -n "Please enter the encrypted drive identifier (eg: sda2) "
    read -r CRYPT < /dev/tty
fi

sudo pacman -S --noconfirm dosfstools parted

sudo mkdir -p /mnt/usbkey
sudo parted -s /dev/"$KEYDRIVE" mklabel gpt
sudo parted -s /dev/"$KEYDRIVE" mkpart FAT32
sudo mkfs.vfat -I /dev/"$KEYDRIVE"
sudo mount /dev/"$KEYDRIVE" /mnt/usbkey

KEYDRIVEUUID=$(blkid /dev/""$KEYDRIVE"" -o value | sed -n "/msdos/{n;p}")
sudo dd bs=1024 count=4 if=/dev/urandom of=/mnt/usbkey/crypt.key iflag=fullblock

clear
echo "Encrypted volume password entry"
echo "========================================================================="
echo ""
sudo cryptsetup luksAddKey /dev/"$ENCRYPTEDDRIVE" /mnt/usbkey/crypt.key --key-slot 1

sudo sed -i -e "s/MODULES=\"/MODULES=\"nls_cp437 vfat\ /g" /etc/mkinitcpio.conf
mkinitcpio -p linux linux-rt-bfq

sudo sed -i -e "s/options\ /options\ cryptkey=UUID=""$KEYDRIVEUUID"":vfat:\/crypt.key\ /g" /boot/loader/entries/arch.conf

sudo umount /mnt/usbkey
sudo rm -rf /mnt/usbkey
clear
echo "USB encryption keyfile setup!"
