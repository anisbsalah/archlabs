#!/usr/bin/env bash
#
# @file Post-Install
# @brief Enabling services, setting swappiness value, adding sudo rights and cleaning up after script.

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
echo ":: sourcing '${HOME}/archlabs/setup.conf'..."
source "${HOME}/archlabs/setup.conf"

echo "
==============================================================================
 Enabling essential services
==============================================================================
"
if [[ ${INSTALL_TYPE} == FULL ]]; then
	services=(acpid avahi-daemon bluetooth cronie cups ntpd NetworkManager reflector sshd tlp wpa_supplicant)
else
	services=(reflector sshd)
fi

for srv in "${services[@]}"; do
	case ${srv} in
	"ntpd")
		ntpd -qg
		systemctl enable "${srv}.service"
		;;
	"reflector")
		systemctl enable "${srv}.timer"
		systemctl enable "${srv}.service"
		;;
	*)
		systemctl enable "${srv}.service"
		;;
	esac
done

if [[ ${SWAPFILE} == true ]]; then
	echo "
==============================================================================
 Decreasing swappiness value
==============================================================================
"
	echo "vm.swappiness=10" | tee /etc/sysctl.d/99-swappiness.conf
fi

echo "
==============================================================================
 Xorg/Keyboard configuration
==============================================================================
"
echo "> Set X11 keymap to: ${KEYMAP}"
mkdir -p /etc/X11/xorg.conf.d
tee "/etc/X11/xorg.conf.d/00-keyboard.conf" <<EOF
# Written by systemd-localed(8), read by systemd-localed and Xorg. It's
# probably wise not to edit this file manually. Use localectl(1) to
# update this file.
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "${KEYMAP}"
EndSection
EOF

echo "
==============================================================================
 Allowing members of group 'wheel' sudo access
==============================================================================
"
# Remove sudo no password rights
sed -i 's/^\(%wheel[[:space:]]*ALL=(ALL)[[:space:]]*NOPASSWD:[[:space:]]*ALL\)$/# \1/g' /etc/sudoers
sed -i 's/^\(%wheel[[:space:]]*ALL=(ALL:ALL)[[:space:]]*NOPASSWD:[[:space:]]*ALL\)$/# \1/g' /etc/sudoers

# Add sudo rights
sed -i 's/^[#[:space:]]*\(%wheel[[:space:]]*ALL=(ALL)[[:space:]]*ALL\)$/\1/g' /etc/sudoers
sed -i 's/^[#[:space:]]*\(%wheel[[:space:]]*ALL=(ALL:ALL)[[:space:]]*ALL\)$/\1/g' /etc/sudoers

echo "
==============================================================================
 Initramfs
==============================================================================
"
# Initramfs
if [[ ${FILESYSTEM} == btrfs ]]; then
	sed -i 's/^MODULES=()/MODULES=(btrfs)/' /etc/mkinitcpio.conf
fi
sed -i 's/^BINARIES=()/BINARIES=(setfont)/' /etc/mkinitcpio.conf
# sed -i 's/^\(HOOKS=["(]*base .*\) keymap consolefont \(.*\)$/\1 sd-vconsole \2/g' /etc/mkinitcpio.conf
# sed -i '/^HOOKS=/s/autodetect\( \|$\)/autodetect microcode\1/g' /etc/mkinitcpio.conf
sed -i 's/^[#[:space:]]*COMPRESSION="zstd"/COMPRESSION="zstd"/' /etc/mkinitcpio.conf
mkinitcpio -P

echo "
==============================================================================
 Cleaning
==============================================================================
"
# Remove 'archlabs' directory
rm -r "${HOME}/archlabs"
rm -r "/home/${USERNAME}/archlabs"

# Replace in the same state
cd "$(pwd)" || exit 1

echo "
==============================================================================
"
sleep 1
exit 0
