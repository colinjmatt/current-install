#!/bin/bash
if [[ ! -d /mnt/offsite-hetzner/Backups ]] && ping -q -c 1 $backupuser.your-storagebox.de >/dev/null; then
    sshfs -o allow_other,reconnect,uid=0,gid=100,umask=003,ServerAliveInterval=15,ServerAliveCountMax=3 $backupuser.your-storagebox.de:/ /mnt/offsite-hetzner
elif [[ -d /mnt/offsite-hetzner/Backups ]] && ping -q -c 1 $backupuser.your-storagebox.de >/dev/null; then
    :
else
   exit 1
fi

rsync -aR --delete \
    /home \
    /root \
    /etc \
    /usr/local/bin/ \
        --include '/usr/local/bin*.*' \
        --exclude '/home/colin/*cache' \
        --exclude '/usr/local/bin/_*' \
    /boot/ \
        --include '/boot/*.txt' \
        --exclude '/boot/*' \
    /tmp/colin-rpi0/

tar -zc \
    /tmp/colin-rpi0/ | \
gpg -se \
    -r admin \
    --batch \
    --yes \
    --pinentry-mode loopback \
    --passphrase-file /root/.gpg-admin \
    -o /mnt/offsite-hetzner/Backups/colin-rpi0/colin-rpi0-"$(date +%Y-%m-%d)".tar.gz.gpg

rm -rf /mnt/colin-rpi0
umount /mnt/offsite-hetzner/
