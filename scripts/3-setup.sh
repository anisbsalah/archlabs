#!/usr/bin/env bash
#
# @file Setup
# @brief Configures installed system, installs microcode, drivers and GRUB boot loader, and creates user account.

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
 Timezone
==============================================================================
"
# Set the timezone
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

echo "> Timezone set to: ${TIMEZONE}"

echo "
==============================================================================
 Localization
==============================================================================
"
# Uncomment the desired locale in /etc/locale.gen
sed -i 's/^[#[:space:]]*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^[#[:space:]]*ar_TN.UTF-8 UTF-8/ar_TN.UTF-8 UTF-8/' /etc/locale.gen
# Generate the locale
locale-gen

# Set the system language
cat >/etc/locale.conf <<EOF
LANG=en_US.UTF-8
LC_TIME=C
EOF

echo "
==============================================================================
 Console keyboard layout and font
==============================================================================
"
# Set the console keyboard layout
echo "KEYMAP=${KEYMAP}" | tee /etc/vconsole.conf
# Set the console font
echo 'FONT=ter-v20b' | tee -a /etc/vconsole.conf

echo "
==============================================================================
 Hostname
==============================================================================
"
# Set the hostname
echo "${HOSTNAME}" | tee /etc/hostname

# Local network hostname resolution
echo '127.0.0.1 localhost' | tee -a /etc/hosts
echo '::1       localhost' | tee -a /etc/hosts
echo "127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}" | tee -a /etc/hosts

echo "
==============================================================================
 Network configuration
==============================================================================
"
# Complete the network configuration for the newly installed environment
pacman -S --noconfirm --needed networkmanager
systemctl enable NetworkManager.service

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
sed -i 's/^[#[:space:]]*COMPRESSION="zstd"/COMPRESSION="zstd"/' /etc/mkinitcpio.conf
mkinitcpio -P

echo "
==============================================================================
 Root password
==============================================================================
"
# Set the root password
echo "root:${ROOT_PASSWORD}" | chpasswd
echo "* 'root' password set."

if [[ ${DESKTOP_ENV} != server ]]; then
	echo "
==============================================================================
 Adding 'sudo no password' rights
==============================================================================
"
	# Add sudo no password rights
	sed -i 's/^[#[:space:]]*\(%wheel[[:space:]]*ALL=(ALL)[[:space:]]*NOPASSWD:[[:space:]]*ALL\)$/\1/g' /etc/sudoers
	sed -i 's/^[#[:space:]]*\(%wheel[[:space:]]*ALL=(ALL:ALL)[[:space:]]*NOPASSWD:[[:space:]]*ALL\)$/\1/g' /etc/sudoers
fi

nc=$(grep -c ^processor /proc/cpuinfo) # nc=$(nproc)
echo "
==============================================================================
 You have ${nc} cores.
 > Changing the makeflags for ${nc} cores.
   As well as changing the compression settings.
==============================================================================
"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[ ${TOTAL_MEM} -gt 8000000 ]]; then
	sed -i "s/[#[:space:]]*MAKEFLAGS=.*/MAKEFLAGS=\"-j${nc}\"/g" /etc/makepkg.conf
	sed -i 's/[#[:space:]]*COMPRESSXZ=.*/COMPRESSXZ=(xz -c -z --threads=0 -)/g' /etc/makepkg.conf
	sed -i 's/[#[:space:]]*COMPRESSZST=.*/COMPRESSZST=(zstd -c -z -q --threads=0 -)/g' /etc/makepkg.conf
fi

echo "
==============================================================================
 'pacman' configuration
==============================================================================
"
# Add color
sed -i 's/^[#[:space:]]*Color/Color\nILoveCandy/' /etc/pacman.conf
# Add parallel downloading
sed -i 's/^[#[:space:]]*ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
# Enable multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

echo "[*] Updating database..."
pacman -Sy

echo "
==============================================================================
 Microcode
==============================================================================
"
# Determine processor type and install microcode
PROC_TYPE=$(lscpu)
if grep -Eiq "GenuineIntel" <<<"${PROC_TYPE}"; then
	echo "[*] Installing Intel microcode..."
	pacman -S --noconfirm --needed intel-ucode
elif grep -Eiq "AuthenticAMD" <<<"${PROC_TYPE}"; then
	echo "[*] Installing AMD microcode..."
	pacman -S --noconfirm --needed amd-ucode
fi

echo "
==============================================================================
 Graphics card drivers
==============================================================================
"
# Graphics card drivers find and install
GPU_TYPE=$(lspci -v | grep -A1 -e VGA -e 3D)

if grep -Eiq "NVIDIA|GeForce" <<<"${GPU_TYPE}"; then
	graphics_drivers=(
		xf86-video-nouveau
		mesa
		lib32-mesa
		# --------------------------------- Hardware video acceleration (VA-API/VDPAU)
		libva-mesa-driver
		lib32-libva-mesa-driver
		libva-utils
		# mesa-vdpau
		# lib32-mesa-vdpau
		# vdpauinfo
	)

elif grep -Eiq "Radeon|AMD" <<<"${GPU_TYPE}"; then
	graphics_drivers=(
		xf86-video-amdgpu
		mesa
		lib32-mesa
		# --------------------------------- Vulkan
		vulkan-icd-loader
		lib32-vulkan-icd-loader
		vulkan-radeon
		lib32-vulkan-radeon
		# --------------------------------- Hardware video acceleration (VA-API/VDPAU)
		libva-mesa-driver
		lib32-libva-mesa-driver
		libva-utils
		# mesa-vdpau
		# lib32-mesa-vdpau
		# vdpauinfo
		# --------------------------------- Translation layers
		# libva-vdpau-driver # (VDPAU adapter)
		# lib32-libva-vdpau-driver
		# libvdpau-va-gl # (VA-API adapter)
	)

elif grep -Eiq "Integrated Graphics Controller" <<<"${GPU_TYPE}"; then
	graphics_drivers=(
		xf86-video-intel
		mesa
		lib32-mesa
		# --------------------------------- Vulkan
		vulkan-icd-loader
		lib32-vulkan-icd-loader
		vulkan-intel
		lib32-vulkan-intel
		# --------------------------------- Hardware video acceleration (VA-API)
		libva-intel-driver # intel-media-driver
		lib32-libva-intel-driver
		libva-utils
		# --------------------------------- Translation layers
		# libva-vdpau-driver # (VDPAU adapter)
		# lib32-libva-vdpau-driver
	)

elif grep -Eiq "Intel Corporation UHD" <<<"${GPU_TYPE}"; then
	graphics_drivers=(
		xf86-video-intel
		mesa
		lib32-mesa
		# --------------------------------- Vulkan
		vulkan-icd-loader
		lib32-vulkan-icd-loader
		vulkan-intel
		lib32-vulkan-intel
		# --------------------------------- Hardware video acceleration (VA-API)
		libva-intel-driver # intel-media-driver
		lib32-libva-intel-driver
		libva-utils
		# --------------------------------- Translation layers
		# libva-vdpau-driver # (VDPAU adapter)
		# lib32-libva-vdpau-driver
	)
fi

if [[ ${DESKTOP_ENV} == kde || ${DESKTOP_ENV} == cinnamon ]]; then
	graphics_drivers=(xf86-video-vesa)
fi

pacman -S --noconfirm --needed "${graphics_drivers[@]}"

echo "
==============================================================================
 Input drivers
==============================================================================
"
# Input drivers install
pacman -S --noconfirm --needed libinput xf86-input-libinput xf86-input-evdev xf86-input-elographics xf86-input-synaptics

echo "
==============================================================================
 Wireless card drivers
==============================================================================
"
# Wireless card drivers find and install
WIRELESS_CARD=$(lspci -v | grep -i network)
if grep -Eiq "Broadcom" <<<"${WIRELESS_CARD}"; then
	if grep -Eiq "BCM43" <<<"${WIRELESS_CARD}"; then
		pacman -S --noconfirm --needed dkms broadcom-wl-dkms
	fi
else
	echo "Nothing to do."
fi

echo "
==============================================================================
 GRUB boot loader
==============================================================================
"
if [[ ! -d "/sys/firmware/efi" ]]; then
	pacman -S --noconfirm --needed grub dosfstools mtools os-prober
	grub-install --target=i386-pc "${DISK}"
	grub-mkconfig -o /boot/grub/grub.cfg
else
	pacman -S --noconfirm --needed grub efibootmgr dosfstools mtools os-prober
	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
	grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "
==============================================================================
 User management
==============================================================================
"
if [[ "$(whoami)" == root ]]; then
	useradd -m -g users -G wheel,audio,video,network,storage,rfkill -s /bin/bash "${USERNAME}"
	printf "* '%s' created and added to wheel,audio,video,network,storage,rfkill Groups.\n* Home directory created.\n* Default shell set to: /bin/bash\n" "${USERNAME}"

	# Set User password
	echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
	echo "* User password set."

	# Copy 'archlabs' project to user's home directory
	cp -R "${HOME}/archlabs" "/home/${USERNAME}/"
	chown -R "${USERNAME}": "/home/${USERNAME}/archlabs"
	echo "> 'archlabs' project copied to the user's home directory."

else
	echo "You are already a user. Proceed with AUR installs"
fi

echo "
==============================================================================

                          SYSTEM READY FOR 4-user.sh

==============================================================================
"
sleep 1
clear
exit 0
