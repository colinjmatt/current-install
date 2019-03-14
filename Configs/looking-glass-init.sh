#!/bin/sh
touch /dev/shm/looking-glass
chown $user:kvm /dev/shm/looking-glass
chmod 660 /dev/shm/looking-glass
