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

if ! mountpoint "$localmount" >/dev/null; then
  sshfs -p "$port" "$user"@"$server":"$remotemount" "$localmount"
elif mountpoint "$localmount" >/dev/null; then
  :
else
  exit 1
fi

if [[ ! -d "$localmount""$directory""$backupname" ]]; then
  mkdir -p "$localmount""$directory""$backupname"
fi

tar -zc \
  --exclude='/home/colin/*cache' \
  --exclude='/home/colin/.config/discord/' \
  --exclude='/home/colin/.config/OCS-Store' \
  --exclude='/home/colin/.config/Opendesktop App' \
  /home \
  /root \
  /etc \
  /usr/local/bin/ | \
gpg -se \
  -r admin \
  --batch \
  --yes \
  --pinentry-mode loopback \
  --passphrase-file "$passphrasefilelocation" \
  -o "$localmount""$directory""$backupname"/"$backupname"-"$(date +%Y-%m-%d)".tar.gz.gpg

find "$localmount""$directory""$backupname"/"$backupname"* -mtime +"$days" -exec rm {} \;

umount "$localmount"
