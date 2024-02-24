#!/usr/bin/env bash
#
# @file Pre-Install
# @brief Contains the steps necessary to partition the disk, format the partitions and mount the file systems.

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
 Installing prerequisites
==============================================================================
"
sed -i 's/^[#[:space:]]*ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
sed -i 's/^[#[:space:]]*Color/Color\nILoveCandy/' /etc/pacman.conf

pacman -Sy
pacman -S --noconfirm archlinux-keyring # Update keyrings to latest to prevent packages failing to install
pacman -S --noconfirm --needed arch-install-scripts glibc
pacman -S --noconfirm --needed gptfdisk btrfs-progs
pacman -S --noconfirm --needed curl reflector rsync

echo "
==============================================================================
 Wiping DATA on disk
==============================================================================
"
# Make sure everything is unmounted before we start
umount -A --recursive /mnt

# Wipe the disk
echo "[*] Wiping all data on ${DISK}..."
wipefs -a -f "${DISK}"
sgdisk -Z "${DISK}" # zap all on disk

echo "
==============================================================================
 Partitioning the disk
==============================================================================
"
create_mbr_partition_table() {
	echo "[*] Creating a new MBR table on ${DISK}..."
	# ---------------------------------------- using 'fdisk'
	#printf "o\nw\n" | fdisk "${DISK}"
	# ---------------------------------------- using 'sfdisk'
	#echo 'label: dos' | sfdisk "${DISK}"
	# ---------------------------------------- using 'parted'
	parted --script "${DISK}" mklabel msdos
}

create_gpt_partition_table() {
	echo "[*] Creating a new GPT table on ${DISK}..."
	# ---------------------------------------- using 'fdisk'
	#printf "g\nw\n" | fdisk "${DISK}"
	# ---------------------------------------- using 'gdisk'
	#printf "o\nY\nw\nY\n" | gdisk "${DISK}"
	# ---------------------------------------- using 'sfdisk'
	#echo 'label: gpt' | sfdisk "${DISK}"
	# ---------------------------------------- using 'sgdisk'
	sgdisk -a 2048 -o "${DISK}"
	# ---------------------------------------- using 'parted'
	# parted --script "${DISK}" mklabel gpt
}

reread_partition_table() {
	partprobe "${DISK}"
	sleep 3
}

partition_disk_bios_mbr() {
	echo "[*] Creating a root partition on ${DISK}..."
	# ---------------------------------------- using 'fdisk'
	#printf "n\np\n\n\n\na\nw\n" | fdisk "$DISK"
	# ---------------------------------------- using 'sfdisk'
	#echo 'type=L, bootable' | sfdisk "${DISK}" # echo ',, L, *' | sfdisk "${DISK}"
	# ---------------------------------------- using 'parted'
	parted --script "${DISK}" mkpart primary "${FILESYSTEM}" 1MiB 100%
	parted --script "${DISK}" set 1 boot on
}

partition_disk_bios_gpt() {
	echo "[*] Creating a BIOS boot partition on ${DISK}..."
	# ---------------------------------------- using 'sgdisk'
	sgdisk --new=1::+1M --typecode=1:ef02 --change-name=1:"BIOS Boot" "${DISK}"
	# ---------------------------------------- using 'parted'
	#parted --script "${DISK}" mkpart ext2 1MiB 2MiB
	#parted --script "${DISK}" set 1 bios_grub on
	# ---------------------------------------- using 'fdisk'
	#printf "n\n\n\n+1M\nt\n4\nw\n" | fdisk "${DISK}"
	# ---------------------------------------- using 'gdisk'
	#printf "n\n\n\n+1M\nef02\nw\nY\n" | gdisk "${DISK}"

	echo "[*] Creating a root partition on ${DISK}..."
	# ---------------------------------------- using 'sgdisk'
	sgdisk --new=2::-0 --typecode=2:8300 --change-name=2:"ArchLinux Root" "${DISK}"
	# ---------------------------------------- using 'parted'
	#parted --script "${DISK}" mkpart "${FILESYSTEM}" 2MiB 100%
	# ---------------------------------------- using 'fdisk'
	#printf "n\n\n\n\nw\n" | fdisk "${DISK}"
	# ---------------------------------------- using 'gdisk'
	#printf "n\n\n\n\n8300\nw\nY\n" | gdisk "${DISK}"
}

partition_disk_uefi_gpt() {
	echo "[*] Creating an EFI System partition on ${DISK}..."
	# ---------------------------------------- using 'sgdisk'
	sgdisk --new=1::+1024M --typecode=1:ef00 --change-name=1:"EFI System Partition" "${DISK}"
	# ---------------------------------------- using 'parted'
	#parted --script "${DISK}" mkpart fat32 1MiB 1025MiB
	#parted --script "${DISK}" set 1 esp on
	# ---------------------------------------- using 'fdisk'
	#printf "n\n\n\n+1024M\nt\n1\nw\n" | fdisk "${DISK}"
	# ---------------------------------------- using 'gdisk'
	#printf "n\n\n\n+1024M\nef00\nw\nY\n" | gdisk "${DISK}"

	echo "[*] Creating a root partition on ${DISK}..."
	# ---------------------------------------- using 'sgdisk'
	sgdisk --new=2::-0 --typecode=2:8300 --change-name=2:"ArchLinux Root" "${DISK}"
	# ---------------------------------------- using 'parted'
	#parted --script "${DISK}" mkpart "${FILESYSTEM}" 1025MiB 100%
	# ---------------------------------------- using 'fdisk'
	#printf "n\n\n\n\nw\n" | fdisk "${DISK}"
	# ---------------------------------------- using 'gdisk'
	#printf "n\n\n\n\n8300\nw\nY\n" | gdisk "${DISK}"
}

auto_disk_layout_bios_mbr() {
	# Create a new MBR partition table
	create_mbr_partition_table
	# Partition the disk
	partition_disk_bios_mbr
	# Notify the kernel about the changes made to the partition table
	reread_partition_table
	ROOT_PARTITION=$(fdisk -l "${DISK}" | grep "^${DISK}" | awk '{print $1}' | awk 'NR==1')
}

auto_disk_layout_bios_gpt() {
	# Create a new GPT partition table
	create_gpt_partition_table
	# Partition the disk
	partition_disk_bios_gpt
	# Notify the kernel about the changes made to the partition table
	reread_partition_table
	ROOT_PARTITION=$(fdisk -l "${DISK}" | grep "^${DISK}" | awk '{print $1}' | awk 'NR==2')
}

auto_disk_layout_uefi_gpt() {
	# Create a new GPT table
	create_gpt_partition_table
	# Partition the disk
	partition_disk_uefi_gpt
	# Notify the kernel about the changes made to the partition table
	reread_partition_table
	EFI_PARTITION=$(fdisk -l "${DISK}" | grep "^${DISK}" | awk '{print $1}' | awk 'NR==1')
	ROOT_PARTITION=$(fdisk -l "${DISK}" | grep "^${DISK}" | awk '{print $1}' | awk 'NR==2')
}

# Auto disk partitioning
if [[ ${BOOT_MODE} == BIOS && ${PARTITION_TABLE} == MBR ]]; then
	auto_disk_layout_bios_mbr
elif [[ ${BOOT_MODE} == BIOS && ${PARTITION_TABLE} == GPT ]]; then
	auto_disk_layout_bios_gpt
elif [[ ${BOOT_MODE} == UEFI ]]; then
	auto_disk_layout_uefi_gpt
fi

echo "
==============================================================================
 Formatting the partitions & Mounting the file systems
==============================================================================
"
# @description Create the btrfs subvolumes.
create_subvolumes() {
	echo "[*] Creating btrfs subvolumes..."
	btrfs subvolume create /mnt/@
	btrfs subvolume create /mnt/@home
	btrfs subvolume create /mnt/@snapshots
	if [[ ${FILESYSTEM} == btrfs && ${SWAPFILE} == true ]]; then
		btrfs subvolume create /mnt/@swap
	fi
	btrfs subvolume create /mnt/@tmp
	btrfs subvolume create /mnt/@var_log
}

# @description Mount all btrfs subvolumes.
mount_subvolumes() {
	echo "[*] Mounting the subvolumes..."
	mount -o "${BTRFS_MOUNT_OPTIONS}",subvol=@ "${ROOT_PARTITION}" /mnt
	mkdir -p /mnt/{home,.snapshots,tmp,var/log}
	mount -o "${BTRFS_MOUNT_OPTIONS}",subvol=@home "${ROOT_PARTITION}" /mnt/home
	mount -o "${BTRFS_MOUNT_OPTIONS}",subvol=@snapshots "${ROOT_PARTITION}" /mnt/.snapshots
	if [[ ${FILESYSTEM} == btrfs && ${SWAPFILE} == true ]]; then
		mkdir -p /mnt/swap
		mount -o "${BTRFS_MOUNT_OPTIONS}",subvol=@swap "${ROOT_PARTITION}" /mnt/swap
	fi
	mount -o "${BTRFS_MOUNT_OPTIONS}",subvol=@tmp "${ROOT_PARTITION}" /mnt/tmp
	mount -o "${BTRFS_MOUNT_OPTIONS}",subvol=@var_log "${ROOT_PARTITION}" /mnt/var/log
}

# @description BTRFS subvolumes creation and mounting.
subvolumes_setup() {
	create_subvolumes
	umount /mnt
	mount_subvolumes
}

# @description Create filesystems and mount partitions.
if [[ ${BOOT_MODE} == UEFI ]]; then
	echo "[*] Formatting the EFI system partition as fat32..."
	mkfs.fat -F 32 "${EFI_PARTITION}"
fi
if [[ ${FILESYSTEM} == btrfs ]]; then
	echo "[*] Formatting the root partition as btrfs..."
	mkfs.btrfs -f "${ROOT_PARTITION}"
	echo "[*] Mounting the root partition..."
	mount -t btrfs "${ROOT_PARTITION}" /mnt
	subvolumes_setup
elif [[ ${FILESYSTEM} == ext4 ]]; then
	echo "[*] Formatting the root partition as ext4..."
	mkfs.ext4 -F "${ROOT_PARTITION}"
	echo "[*] Mounting the root partition..."
	mount -t ext4 "${ROOT_PARTITION}" /mnt
fi
if [[ ${BOOT_MODE} == UEFI ]]; then
	echo "[*] Mounting the EFI system partition..."
	mount --mkdir "${EFI_PARTITION}" /mnt/boot
fi

# @description If mounting failed, reboot.
if ! grep -qs '/mnt' /proc/mounts; then
	echo "Drive is not mounted! Can not continue." && sleep 1
	echo "Rebooting in 3s..." && sleep 1
	echo "Rebooting in 2s..." && sleep 1
	echo "Rebooting in 1s..." && sleep 1
	reboot now
fi

echo "
==============================================================================

                      SYSTEM READY FOR 2-arch-install.sh
                         
==============================================================================
"
sleep 1
clear
exit 0
