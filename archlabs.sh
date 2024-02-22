#!/usr/bin/env bash
#
# @file Archlabs
# @brief Entrance script that launches children scripts for each phase of installation.

# Find the name of the project folder
set -a
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
set +a

# Set console font
setfont ter-v18b

# Update system clock
timedatectl set-ntp true

clear
echo "
==============================================================================
        █████╗ ██████╗  ██████╗██╗  ██╗██╗      █████╗ ██████╗ ███████╗
       ██╔══██╗██╔══██╗██╔════╝██║  ██║██║     ██╔══██╗██╔══██╗██╔════╝
       ███████║██████╔╝██║     ███████║██║     ███████║██████╔╝███████╗
       ██╔══██║██╔══██╗██║     ██╔══██║██║     ██╔══██║██╔══██╗╚════██║
       ██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║  ██║██████╔╝███████║
       ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝
==============================================================================
                   Automated Arch Linux Installation Script
==============================================================================
"
sleep 1
clear
(bash "${PROJECT_DIR}/scripts/0-startup.sh") |& tee 0-startup.log
source "${PROJECT_DIR}/setup.conf"
(bash "${PROJECT_DIR}/scripts/1-pre-install.sh") |& tee 1-pre-install.log
(bash "${PROJECT_DIR}/scripts/2-arch-install.sh") |& tee 2-arch-install.log
(arch-chroot /mnt "${HOME}/archlabs/scripts/3-setup.sh") |& tee 3-setup.log
if [[ ${DESKTOP_ENV} != "server" ]]; then
	(arch-chroot /mnt /usr/bin/runuser -u "${USERNAME}" -- bash "/home/${USERNAME}/archlabs/scripts/4-user.sh") |& tee 4-user.log
fi
(arch-chroot /mnt bash "${HOME}/archlabs/scripts/5-post-install.sh") |& tee 5-post-install.log
cp -v ./*.log "/mnt/home/${USERNAME}/"

echo "
==============================================================================
        █████╗ ██████╗  ██████╗██╗  ██╗██╗      █████╗ ██████╗ ███████╗
       ██╔══██╗██╔══██╗██╔════╝██║  ██║██║     ██╔══██╗██╔══██╗██╔════╝
       ███████║██████╔╝██║     ███████║██║     ███████║██████╔╝███████╗
       ██╔══██║██╔══██╗██║     ██╔══██║██║     ██╔══██║██╔══██╗╚════██║
       ██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║  ██║██████╔╝███████║
       ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝
==============================================================================
                   Automated Arch Linux Installation Script
==============================================================================
                 Done - Please eject install media and reboot
==============================================================================
                  Type 'exit', 'umount -R /mnt' and 'reboot'
==============================================================================
"
