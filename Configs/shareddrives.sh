#!/bin/bash
sleep 5
if [[ -e /mnt/Downloads/Complete ]]; then :
else
while true; do
    ping -q -c 1 SHARED-VM > /dev/null
    if [[ $? -eq 0 ]]; then
        mount -t nfs -o vers=4,soft,_netdev,bg SHARED-VM:srv/nfs/Backup /mnt/Backup
        mount -t nfs -o vers=4,soft,_netdev,bg SHARED-VM:srv/nfs/Downloads /mnt/Downloads
        mount -t nfs -o vers=4,soft,_netdev,bg SHARED-VM:srv/nfs/FTP /mnt/FTP
        mount -t nfs -o vers=4,soft,_netdev,bg SHARED-VM:srv/nfs/Media /mnt/Media
        mount -t nfs -o vers=4,soft,_netdev,bg SHARED-VM:srv/nfs/Store /mnt/Store
        mount -t nfs -o vers=4,soft,_netdev,bg SHARED-VM:srv/nfs/Vault /mnt/Vault
        break
    else
        sleep 1
        continue
    fi
done
fi
