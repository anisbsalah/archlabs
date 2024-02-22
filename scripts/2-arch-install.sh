#!/usr/bin/env bash
#
# @file Arch-Install
# @brief Updates the mirror list, installs Arch Linux on the selected drive and generates fstab.

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
echo ":: sourcing '${PROJECT_DIR}/setup.conf'..."
source "${PROJECT_DIR}/setup.conf"

echo "
==============================================================================
 Evaluating and finding closest mirrors for Arch repositories
==============================================================================
"
printf "This may take a while...\n\n"
while true; do
	pgrep -x reflector &>/dev/null || break
	sleep 2
done

cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

# Ranking mirrors by country
country_iso=$(curl -4 ifconfig.co/country-iso)
echo "[*] Setting up ${country_iso} mirrors for faster downloads..."
reflector --verbose --download-timeout 60 \
	--country "${country_iso}" \
	--protocol https \
	--age 24 \
	--latest 20 \
	--fastest 10 \
	--sort rate \
	--save /etc/pacman.d/mirrorlist

mkdir /mnt &>/dev/null # Hiding error message if any
echo "
==============================================================================
 Installing Arch Linux on main drive
==============================================================================
"
base_pkgs=("base" "base-devel")
kernel_pkgs=("linux" "linux-headers" "linux-docs")
firmware_pkgs=("linux-firmware" "sof-firmware")
doc_pkgs=("man-db" "man-pages" "texinfo")
extra_pkgs=("bash-completion" "btrfs-progs" "git" "nano" "reflector" "sudo" "terminus-font" "zstd")

# Install the base system
pacstrap -K /mnt "${base_pkgs[@]}" "${kernel_pkgs[@]}" "${firmware_pkgs[@]}" "${doc_pkgs[@]}" "${extra_pkgs[@]}"

echo "
==============================================================================
 Generating fstab
==============================================================================
"
genfstab -U /mnt >>/mnt/etc/fstab
echo "> Generated /etc/fstab:
"
cat /mnt/etc/fstab

if [[ ${SWAPFILE} == true ]]; then
	echo "
==============================================================================
 Swap file creation
==============================================================================
"
	# Create swap file
	ram=$(free -m -t | awk 'NR == 2 {print $2}')
	result=$((ram < 4096 ? ram : 4096))
	result=$((result + ((ram - 4096 > 0 ? ram - 4096 : 0) / 2)))
	result=$((result < 32 * 1024 ? result : 32 * 1024))
	SWAPFILE_SIZE="${result}"

	if [[ ${FILESYSTEM} == btrfs ]]; then
		btrfs filesystem mkswapfile --size "${SWAPFILE_SIZE}M" --uuid clear /mnt/swap/swapfile
		swapon /mnt/swap/swapfile
		echo "# Swap
/swap/swapfile    none    swap    defaults  0   0" >>/mnt/etc/fstab
	elif [[ ${FILESYSTEM} == ext4 ]]; then
		dd if=/dev/zero of=/mnt/swapfile bs=1M count="${SWAPFILE_SIZE}" status=progress # Create a swap file
		chmod 0600 /mnt/swapfile                                                        # Set permissions
		mkswap -U clear /mnt/swapfile                                                   # Format the file to swap
		swapon /mnt/swapfile                                                            # Activate the swap file
		echo "# Swap
/swapfile    none    swap    defaults  0   0" >>/mnt/etc/fstab # Add entry to fstab
	fi
fi

echo "
==============================================================================
 Copying 'archlabs' project to the new system
==============================================================================
"
# Copy 'archlabs' directory to the new system
cp -R "${PROJECT_DIR}" /mnt/root/archlabs

echo "
==============================================================================

                         SYSTEM READY FOR 3-setup.sh
                         
==============================================================================
"
sleep 1
clear
exit 0
