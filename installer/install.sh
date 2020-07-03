#!/bin/bash
###### install.sh FILE

# Load configuration file
. ./installer/files/install.config
. ./installer/helpers.sh


# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT


# set a keyboard layout
loadkeys us

# update the system clock
timedatectl set-ntp true

# check if the DISK_NAME is set valid
# if not so, get it from the user
while [ ! -b "$DISK_NAME" ]; do
    read -p 'Disk device name is incorrect. Please type your disk device name to format (e.g. /dev/sda). Check twice before continuing: ' DISK_NAME;
done


# if user wants to use a layout file
if [ "$USE_LAYOUT" == 'Y' ]; then
    LAYOUT_FILE="./installer/files/$LAYOUT_FILE"

	# check if the layout file does exist
    if [ ! -f "$LAYOUT_FILE" ]; then echo "There's no such file: $LAYOUT_FILE. Exiting..." && exit; fi

    sfdisk "$DISK_NAME" < "$LAYOUT_FILE";
# if doesn't want to use a layout file
else
    read -p 'OK, if there is no file, then you should have set the layout of your disks by editing the /installer/helpers.sh file. Did you? (y/N): ' did_set

    if [ ! $did_set = 'y' ] && [ ! $did_set = 'Y' ]; then
        print_line "Please edit the script according to your preferences.\nExiting..."
        exit
    else
		# use format_partitions function with the argument DISK_NAME
        format_partitions $DISK_NAME
    fi
fi

print_line "$DISK_NAME has been successfully formatted."



# CREATE A NEW LUKS CONTAINER
#############################

# create an encrypted LUKS container
cryptsetup luksFormat --type luks2 "$LVM_PART"

# open it
cryptsetup open "$LVM_PART" cryptlvm

# create a physical volume on top of the opened LUKS container
pvcreate /dev/mapper/cryptlvm

# create a new volume group named volumees
vgcreate volumees /dev/mapper/cryptlvm



# CREATE LOGICAL VOLUMES ON THE volumees GROUP
##############################################

# swap
lvcreate -L "$SWAP_VOLUME" volumees -n swap

# root
lvcreate -L "$ROOT_VOLUME" volumees -n root

# home
lvcreate -l "$HOME_VOLUME" volumees -n home



# FORMAT FILESYSTEMS ON EACH LOGICAL VOLUME
###########################################

# root as ext4
mkfs.ext4 /dev/volumees/root

# home as ext4
mkfs.ext4 /dev/volumees/home

# efi as fat32
mkfs.fat -F32 "$EFI_PART"

# swap as swap :D
mkswap /dev/volumees/swap



# MOUNT FILESYSTEMS
###################

# root at /mnt
mount /dev/volumees/root /mnt

# home at /mnt/home
mkdir /mnt/home
mount /dev/volumees/home /mnt/home

# swap
swapon /dev/volumees/swap

# boot at /mnt/boot
mkdir /mnt/boot
mount "$EFI_PART" /mnt/boot



# START INSTALLING
##################

print_line "Starting installation..."

# update the mirrorlist of pacman
cat ./installer/files/pacman.mirrorlist > /etc/pacman.d/mirrorlist

# update
pacman -Syy

#  use the pacstrap script to install essential packages
pacstrap /mnt base base-devel linux linux-firmware

# generate an fstab file. -U for UUID, -L for labels
genfstab -U /mnt >> /mnt/etc/fstab

# copy chroot.sh file to run in the new system
cp -r ./installer /mnt

# also copy the authorized_keys so can ssh into the system after installing
cp ~/.ssh/authorized_keys /mnt/installer

# now run the chroot.sh by changing the root into the new system
arch-chroot /mnt ./installer/chroot.sh

rm -rf /mnt/installer/

print_line "Congratulations! Your Arch has been successfully installed (hopefully)."
read -p "Press any key to ::unmount file systems:: and ::reboot::."

umount -R /mnt
systemctl reboot

