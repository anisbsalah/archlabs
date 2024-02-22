#!/usr/bin/env bash
#
# @file Startup
# @brief This script will ask users about their preferences like disk, file system, timezone, keyboard layout, user name, passwords, etc.
# @stdout Output routed to 0-startup.log
# @stderror Output routed to 0-startup.log

CONFIG_FILE="${PROJECT_DIR}/setup.conf"
if [[ ! -f ${CONFIG_FILE} ]]; then # check if file exists
	touch -f "${CONFIG_FILE}"         # create file if not exists
fi

# @description Displays Arch logo
# @noargs
logo() {
	# This will be shown on every set as user is progressing
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
               Please select pre-setup settings for your system
==============================================================================
"
}

select_option() {
	local num_columns=$1 # Desired number of columns (passed as an argument)
	shift
	local options=("$@") # Array of options passed as arguments
	local num_options=${#options[@]}

	tput civis # Hide the cursor before displaying the menu

	# Calculate the number of rows and columns for the menu
	local num_rows=$(((num_options + num_columns - 1) / num_columns))
	local max_option_length=0

	# Find the maximum length among the options
	for option in "${options[@]}"; do
		local option_length=${#option}
		if [[ ${option_length} -gt ${max_option_length} ]]; then
			max_option_length=${option_length}
		fi
	done

	# Calculate the width of each column based on the maximum option length
	local column_width=$((max_option_length + 7)) # Change the value to adjust the spacing between columns

	print_menu() {
		tput sc # Save the cursor position
		local row=0
		local col=0
		for option in "${options[@]}"; do
			if [[ ${row} -eq ${selected_row} && ${col} -eq ${selected_col} ]]; then
				printf "     \e[1m\e[7m %-${column_width}s\e[0m" "${option}" # Highlight the selected option
			else
				printf "      %-${column_width}s\e[0m" "${option}" # Clear formatting for non-selected options
			fi

			((col++))
			if [[ ${col} -eq ${num_columns} ]]; then
				col=0
				((row++))
				echo
			fi
		done
		tput rc # Restore the cursor position
	}

	local selected_row=0
	local selected_col=0
	local max_rows=$((num_rows - 1))
	local max_cols=$((num_columns - 1))

	while true; do
		print_menu # Print the menu with the selected option highlighted

		read -rsn1 key # Read a single character of input
		case ${key} in
		$'\e')                  # Handle arrow keys
			read -rsn2 -t 0.1 key2 # Read the second part of the escape sequence
			case ${key2} in
			"[A") # Up arrow
				((selected_row--))
				if [[ ${selected_row} -lt 0 ]]; then
					selected_row=${max_rows}
					((selected_col--))
					if [[ ${selected_col} -lt 0 ]]; then
						selected_col=${max_cols}
					fi
				fi
				;;
			"[B") # Down arrow
				((selected_row++))
				if [[ ${selected_row} -gt ${max_rows} ]]; then
					selected_row=0
					((selected_col++))
					if [[ ${selected_col} -gt ${max_cols} ]]; then
						selected_col=0
					fi
				fi
				;;
			"[C") # Right arrow
				((selected_col++))
				if [[ ${selected_col} -gt ${max_cols} ]]; then
					selected_col=0
					((selected_row++))
					if [[ ${selected_row} -gt ${max_rows} ]]; then
						selected_row=0
					fi
				fi
				;;
			"[D") # Left arrow
				((selected_col--))
				if [[ ${selected_col} -lt 0 ]]; then
					selected_col=${max_cols}
					((selected_row--))
					if [[ ${selected_row} -lt 0 ]]; then
						selected_row=${max_rows}
					fi
				fi
				;;
			*) ;;
			esac
			;;
		"" | " ") # Enter key or space key
			break    # Exit the loop and select the current option
			;;
		*) ;;
		esac
	done

	tput cnorm             # Show the cursor after the menu is displayed
	tput cud "${num_rows}" # Move the cursor down by the number of rows in the menu
	tput cud 1             # Move the cursor down by one line
	selected_option=${options[selected_row * num_columns + selected_col]}
}

# @description Sets options in setup.conf
# @arg $1 string Configuration variable.
# @arg $2 string Configuration value.
set_option() {
	if grep -Eq "^${1}.*" "${CONFIG_FILE}"; then # check if option exists
		sed -i -e "/^${1}.*/d" "${CONFIG_FILE}"     # delete option if exists
	fi
	echo "${1}=${2}" >>"${CONFIG_FILE}" # add option
}

set_password() {
	read -rs -p "[#?] Choose a password for the '$1' account: " PASSWORD1
	echo
	read -rs -p "[#?] Confirm password: " PASSWORD2
	echo
	if [[ ${PASSWORD1} == "${PASSWORD2}" ]]; then
		set_option "$2" "${PASSWORD1}"
	else
		printf "\nERROR! Passwords do not match.\nTry again.\n\n"
		set_password "$1" "$2"
	fi
}

root_check() {
	if [[ "$(id -u)" != "0" ]]; then
		echo "ERROR! This script must be run under the 'root' user."
		exit 0
	fi
}

docker_check() {
	if awk -F/ '$2 == "docker"' /proc/self/cgroup | read -r; then
		echo "ERROR! Docker container is not supported (at the moment)."
		exit 0
	elif [[ -f /.dockerenv ]]; then
		echo "ERROR! Docker container is not supported (at the moment)."
		exit 0
	fi
}

arch_check() {
	if [[ ! -e /etc/arch-release ]]; then
		echo "ERROR! This script must be run in Arch Linux."
		exit 0
	fi
}

pacman_check() {
	if [[ -f /var/lib/pacman/db.lck ]]; then
		echo "ERROR! pacman is blocked."
		echo "If not running, remove /var/lib/pacman/db.lck"
		exit 0
	fi
}

background_checks() {
	root_check
	arch_check
	pacman_check
	docker_check
}

# @description Gathers username and passwords to be used for installation.
userinfo() {
	read -rep "[#?] Username for your account: " username
	set_option "USERNAME" "${username,,}" # convert to lower case as in issue #109
	read -rep "[#?] Enter the hostname for this system: " hostname
	set_option "HOSTNAME" "${hostname}"
	set_password "root" "ROOT_PASSWORD"
	set_password "user" "USER_PASSWORD"
}

# @description Disk selection for drive to be used with installation.
diskpart() {
	printf "[#?] Select the disk device you want to install Arch Linux on:\n\n"
	options=()
	while read -r type kname size; do
		if [[ ${type} == "disk" ]]; then
			options+=("/dev/${kname} (${size})")
		fi
	done < <(lsblk -n --output TYPE,KNAME,SIZE)

	select_option 2 "${options[@]}"
	disk=${selected_option% (*}
	set_option "DISK" "${disk}"

	echo "> You selected: ${selected_option}
==============================================================
 THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK.
 Please make sure you know what you are doing, because
 after formatting your disk there is no way to get data back.
==============================================================
"
	printf ":: Are you sure you want to wipe all data on %s ?\n\n" "${disk}"
	options=("YES" "NO")
	select_option 2 "${options[@]}"
	if [[ ${selected_option} != "YES" ]]; then
		echo "Aborted."
		exit 1
	fi

	drivessd
}

# @description Choose whether drive is SSD or not.
drivessd() {
	printf ":: Is this a SSD?\n\n"
	options=("Yes" "No")
	select_option 2 "${options[@]}"

	case ${selected_option} in
	Yes)
		set_option "BTRFS_MOUNT_OPTIONS" "defaults,noatime,compress=zstd,ssd,commit=120"
		;;
	No)
		set_option "BTRFS_MOUNT_OPTIONS" "defaults,noatime,compress=zstd,commit=120"
		;;
	*)
		echo "Invalid choice! Try again."
		drivessd
		;;
	esac
}

# @description Choose which partition table to create (GPT/MBR).
partition_table() {
	if [[ ! -d "/sys/firmware/efi" ]]; then
		printf "> The system is booted in BIOS mode.\n\n"
		set_option "BOOT_MODE" "BIOS"
		echo "[#?] Choose the partition table to create on ${disk}:
		"
		options=("GPT" "MBR")
		select_option 1 "${options[@]}"
		set_option "PARTITION_TABLE" "${selected_option}"
	else
		set_option "BOOT_MODE" "UEFI"
		set_option "PARTITION_TABLE" "GPT"
	fi
}

# @description This function will handle file systems. At this movement we are handling only btrfs and ext4.
# Others will be added in future.
filesystem() {
	printf "[#?] Select the appropriate file system for the root partition:\n\n"
	options=("btrfs" "ext4")
	select_option 1 "${options[@]}"

	case ${selected_option} in
	"btrfs") set_option "FILESYSTEM" "btrfs" ;;
	"ext4") set_option "FILESYSTEM" "ext4" ;;
	*)
		echo "Invalid choice! Try again."
		filesystem
		;;
	esac
}

# @description Asks to create a swap file
swapfile() {
	printf ":: Do you want to create a swap file on your system?\n\n"
	options=("Yes" "No")
	select_option 1 "${options[@]}"

	case ${selected_option} in
	"Yes") set_option "SWAPFILE" "true" ;;
	"No") set_option "SWAPFILE" "false" ;;
	*)
		echo "Invalid choice! Try again."
		swapfile
		;;
	esac
}

# @description Choose Desktop Environment.
desktopenv() {
	printf "[#?] Select your desired desktop environment:\n\n"
	options=($(for f in pkg-files/*.txt; do echo "${f}" | sed -r "s/.+\/(.+)\..+/\1/;/pkgs/d"; done))
	select_option 2 "${options[@]}"
	desktop_env=${selected_option}
	set_option "DESKTOP_ENV" "${desktop_env}"
}

# @description Choose whether to do full or minimal installation.
installtype() {
	printf "[#?] Select the type of installation:\n
    - Full: Installs full featured desktop environment, with added apps and themes needed for everyday use.
    - Minimal: Installs only few selected apps to get you started.\n\n"
	options=("FULL" "MINIMAL")
	select_option 1 "${options[@]}"
	install_type=${selected_option}
	set_option "INSTALL_TYPE" "${install_type}"
}

# @description Choose AUR helper.
aurhelper() {
	printf "[#?] Select your desired AUR helper:\n\n"
	options=("yay" "yay-bin" "paru" "paru-bin" "trizen" "pikaur" "pakku" "aurman" "aura" "none")
	select_option 2 "${options[@]}"
	aur_helper=${selected_option}
	set_option "AUR_HELPER" "${aur_helper}"
}

# @description Choose whether to install flatpak or not.
flatpak() {
	printf ":: Do you want to install flatpak?\n\n"
	options=("Yes" "No")
	select_option 1 "${options[@]}"
	case ${selected_option} in
	"Yes") set_option "FLATPAK" "true" ;;
	"No") set_option "FLATPAK" "false" ;;
	*)
		echo "Invalid choice! Try again."
		flatpak
		;;
	esac
}

# @description Detects and sets timezone.
timezone() {
	#TIMEZONE="$(timedatectl show --property=Timezone --value)"
	TIMEZONE="$(wget -O - -q http://geoip.ubuntu.com/lookup | sed -n -e 's/.*<TimeZone>\(.*\)<\/TimeZone>.*/\1/p')"
	echo "> System detected your timezone to be '${TIMEZONE}'"
	printf "  Is this correct?\n\n"
	options=("Yes" "No")
	select_option 2 "${options[@]}"

	case ${selected_option} in
	"Yes")
		set_option "TIMEZONE" "${TIMEZONE}"
		;;
	"No")
		read -rep "[#?] Enter your timezone (e.g. Africa/Tunis): " new_timezone
		set_option "TIMEZONE" "${new_timezone}"
		;;
	*)
		echo "Invalid choice! Try again."
		timezone
		;;
	esac
}

# @description Sets user's keyboard mapping.
keymap() {
	printf "[#?] Select your keyboard layout from this list:\n\n"
	options=("us" "by" "ca" "cf" "cz" "de" "dk" "es" "et" "fa" "fi" "fr" "gr" "hu" "il" "it" "lt" "lv" "mk" "nl" "no" "pl" "ro" "ru" "sg" "ua" "uk")
	select_option 4 "${options[@]}"
	keymap=${selected_option}
	set_option "KEYMAP" "${keymap}"
}

# Starting functions
background_checks
clear
logo
userinfo
clear
logo
diskpart
clear
logo
partition_table
clear
logo
filesystem
clear
logo
swapfile
clear
logo
desktopenv
if [[ ${desktop_env} != server ]]; then
	clear
	logo
	installtype
	clear
	logo
	aurhelper
	clear
	logo
	flatpak
else
	set_option "INSTALL_TYPE" "MINIMAL"
	set_option "AUR_HELPER" "none"
	set_option "FLATPAK" "false"
fi
clear
logo
timezone
clear
logo
keymap
clear
exit 0
