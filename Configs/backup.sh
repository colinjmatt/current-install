#!/bin/bash
# Customised for spledik.home.matthews.uk.net
user=""
server=""
port="22"
remotemount=""
directory=""
passphrasefilelocation=""
backupname=""
days="90"

# Create remote directory
ssh -p "$port" "$user@$server" "mkdir -p \"$remotemount$directory$backupname\""

# Generate backup, compress with pigz, encrypt with AES128, and transfer via SSH
tar -c \
  --exclude='/home/colin/.cache' \
  --exclude='/home/colin/.config/discord' \
  --exclude='/home/colin/.config/heroic' \
  --exclude='/home/colin/.config/legendary' \
  --exclude='/home/colin/.config/lutris' \
  --exclude='/home/colin/.config/unity3d' \
  --exclude='/home/colin/.config/steamtinkerlaunch' \
  --exclude='/home/colin/.local/share/lutris' \
  --exclude='/home/colin/.local/share/Steam' \
  --exclude='/home/colin/.local/share/umu' \
  --exclude='/home/colin/.config/.factorio' \
  --exclude='/home/colin/.config/.gemini' \
  --exclude='/home/colin/.mozilla' \
  --exclude='/home/colin/.steam' \
  --exclude='/home/colin/.vscode-oss' \
  --exclude='/home/colin/.wine' \
  --exclude='/home/colin/Games' \
  /home \
  /root \
  /etc \
  /usr/local/bin/ 2>/dev/null | \
pigz --fast | \
gpg -se \
  -r admin \
  --batch \
  --yes \
  --pinentry-mode loopback \
  --passphrase-file "$passphrasefilelocation" \
  --cipher-algo AES128 | \
ssh -p "$port" "$user@$server" "cat > \"$remotemount$directory$backupname/$backupname-$(date +%Y-%m-%d).tar.gz.gpg\""

# Remove old backups remotely
ssh -p "$port" "$user@$server" "find \"$remotemount$directory$backupname\" -name \"$backupname-*\" -mtime +$days -exec rm {} \;"