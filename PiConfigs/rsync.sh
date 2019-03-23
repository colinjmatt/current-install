#!/bin/sh
mount -t nfs SHARED-VM:/srv/nfs/Backup /mnt/backup/
rsync -aR --delete /home /root /etc /mnt/Backup/colin-rpi0/
rsync -aR --delete /usr/local/bin/ --include '/usr/local/bin*.*' --exclude '/home/colin/*cache' --exclude '/usr/local/bin/_*' /mnt/Backup/colin-rpi0/
rsync -aR --delete /boot/ --include '/boot/*.txt' --exclude '/boot/*' /mnt/Backup/colin-rpi0/
umount /mnt/Backup
