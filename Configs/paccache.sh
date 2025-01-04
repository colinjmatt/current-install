#!/bin/bash
echo "Removing old pacman package versions from the cache, but keeping the 2 most recent."
paccache -rk2
echo ""
echo "Removing all pacman packages from the cache that are no longer installed"
paccache -ruk0
echo ""

echo "Removing old paru package versions from the cache, but keeping the 2 most recent."
paccache -rk2 -c /home/"$user"/.cache/paru/*/
echo ""
echo "Removing all paru packages from the cache that are no longer installed"
paccache -ruk0 /home/"$user"/.cache/paru/*/
echo ""