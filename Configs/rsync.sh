#!/bin/sh
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
    /mnt/Backup/$hostname
