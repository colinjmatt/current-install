#!/bin/sh
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
    /usr/share/icons/ \
    /usr/share/themes/ \
    --include '/usr/share/themes/*.keep' \
    --include '/usr/share/icons/*.keep' \
    --exclude '/home/colin/*cache' \
    --exclude '/home/colin/.mozilla' \
    --exclude '/usr/share/themes/*' \
    --exclude '/usr/share/icons/*' \
    --exclude '/home/colin/.config/discord/' \
    --exclude '/home/colin/.config/OCS-Store' \
    --exclude '/home/colin/.config/Opendesktop App' \
    /mnt/Backup/colin-pc

tar -zc \
    /mnt/Backup/colin-pc/ | \
gpg -se \
    -r admin \
    --batch \
    --yes \
    --pinentry-mode loopback \
    --passphrase-file /root/.gpg-admin \
    -o /mnt/offsite-hetzner/Backups/colin-pc/colin-pc-"$(date +%Y-%m-%d)".tar.gz.gpg

rm -rf /tmp/colin-pc
umount /mnt/offsite-hetzner/
