#!/bin/bash
echo "Removing old pacman package versions from the cache, but keeping the 2 most recent."
paccache -rk2
echo "Removing all pacman packages from the cache that are no longer installed"
paccache -ruk0


echo "Removing old paru package versions from the cache, but keeping the 2 most recent."
paccache -rk2 -c /home/$user/.cache/paru/*/
echo "Removing all paru packages from the cache that are no longer installed"
paccache -ruk0 /home/$user/.cache/paru/*/