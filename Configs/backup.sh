#!/bin/bash
user=""
server=""
port=""
remotemount=""
localmount=""
directory=""
passphrasefilelocation=""
backupname=""
days="90"

if [[ ! -d "$localmount" ]]; then
  mkdir -p "$localmount"
fi

if [[ ! -d "$localmount""$directory" ]]; then
  sshfs -p "$port" "$user"@"$server":"$remotemount" "$localmount"
elif [[ -d "$localmount""$directory" ]]; then
  :
else
  exit 1
fi

if [[ ! -d "$localmount""$directory" ]]; then
  mkdir -p "$localmount""$directory"
fi

tar -zc \
  --exclude='/home/colin/*cache' \
  --exclude='/home/colin/.mozilla' \
  --exclude='/home/colin/.config/discord/' \
  --exclude='/home/colin/.config/OCS-Store' \
  --exclude='/home/colin/.config/Opendesktop App' \
  /home \
  /root \
  /etc \
  /usr/local/bin/ \
  /usr/share/icons/*.keep \
  /usr/share/themes/*.keep | \
gpg -se \
  -r admin \
  --batch \
  --yes \
  --pinentry-mode loopback \
  --passphrase-file "$passphrasefilelocation" \
  -o "$localmount""$directory""$backupname"/"$backupname"-"$(date +%Y-%m-%d)".tar.gz.gpg

find "$localmount""$directory""$backupname"/"$backupname"* -mtime +"$days" -exec rm {} \;

umount "$localmount"
