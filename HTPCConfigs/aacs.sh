#!/bin/bash
if [[ -f /tmp/keydb.cfg.zip ]]; then
  rm /tmp/keydb.cfg.zip
fi
wget http://fvonline-db.bplaced.net/fv_download.php?lang=eng -O /tmp/keydb.cfg.zip
unzip /tmp/keydb.cfg -d /home/htpc/.config/aacs/
mv /home/htpc/.config/aacs/keydb.cfg /home/htpc/.config/aacs/KEYDB.cfg
chmod 0644 /home/htpc/.config/aacs/KEYDB.cfg
chown htpc:htpc /home/htpc/.config/aacs/KEYDB.cfg
rm /tmp/keydb.cfg.zip
