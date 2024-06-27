#!/bin/bash
paccache -rk2
paccache -ruk1

paccache -rk2 -c /home/$user/.cache/paru/*/
paccache -ruk0 /home/$user/.cache/paru/*/