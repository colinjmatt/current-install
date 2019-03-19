#!/bin/sh
reboot=$( systemctl list-jobs | grep -Eq 'reboot.target.*start' && echo "rebooting" || echo "not_rebooting" )
if [ $reboot = "not_rebooting" ]; then
    ssh colin@COLIN-RPI0 'sudo shutdown now'
    exit 0
elif [ $reboot = "rebooting" ]; then
    ssh colin@COLIN-RPI0 'sudo reboot'
    exit 0
fi
