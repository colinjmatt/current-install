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

tar -zc --verbose \
  --exclude='/home/$user/.cache' \
  --exclude='/home/$user/.config/discord' \
  --exclude='/home/$user/.config/heroic' \
  --exclude='/home/$user/.config/legendary' \
  --exclude='/home/$user/.config/lutris' \
  --exclude='/home/$user/.config/unity3d' \
  --exclude='/home/$user/.config/steamtinkerlaunch' \
  --exclude='/home/$user/.local/share/lutris' \
  --exclude='/home/$user/.local/share/Steam' \
  --exclude='/home/$user/.mozilla' \
  --exclude='/home/$user/.steam' \
  --exclude='/home/$user/.wine' \
  --exclude='/home/$user/Games' \
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