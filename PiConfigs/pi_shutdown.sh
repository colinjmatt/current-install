#!/bin/bash
while true; do
    if ping -q -c 1 192.168.0.101 > /dev/null; then
        sleep 1
        continue
    else
        sleep 25
        if ping -q -c 1 192.168.0.101 > /dev/null; then
            sleep 1
            continue
        else
            shutdown now
        fi
    fi
done
