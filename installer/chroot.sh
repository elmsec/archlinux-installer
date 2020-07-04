#!/bin/bash

. ./installer/files/install.config
. ./installer/helpers.sh


# UUIDs
EFI_UUID=$(blkid -o value -s UUID $EFI_PART)
LVM_UUID=$(blkid -o value -s UUID $LVM_PART)

# set local time
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime
hwclock --systohc

# update locales
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
echo 'en_US. ISO-8859-1' >> /etc/locale.gen
echo 'tr_TR.UTF-8 UTF-8' >> /etc/locale.gen
echo 'tr_TR ISO-8859-9' >> /etc/locale.gen

echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf

# generate locales
locale-gen

# set host name
echo "$MACHINE_NAME" > /etc/hostname

# set /etc/hosts
(
echo "127.0.0.1     localhost"
echo "::1           localhost"
echo "127.0.1.1     $MACHINE_NAME"
) > /etc/hosts



# CREATE USERS AND SET PASSWORDS
################################

# root password
print_line "Please type the password of your root user."
passwd

# create new regular user with the "wheel" group to use sudo
useradd -U -G wheel -m -s /bin/bash "$USERNAME"

# set the password of the regular user
print_line "Please type the password of the user '$USERNAME'."
passwd "$USERNAME"

# add to the sudoers
sed -i "s,^root ALL=(ALL) ALL,\0\n$USERNAME ALL=(ALL) ALL," /etc/sudoers


# PACMAN
########

# enable multilib
sed -i "s,^#\[multilib\],[multilib]\nInclude = /etc/pacman.d/mirrorlist," /etc/pacman.conf

# update pacman mirrorlist
cat ./installer/files/pacman.mirrorlist > /etc/pacman.d/mirrorlist

# update
pacman -Syy

# install essential packages
pacman -S --noconfirm grub efibootmgr sudo lvm2 man networkmanager xorg-server xorg-xinit lib32-mesa mesa sddm plasma plasma-nm bash-completion vlc yakuake okular ark firefox gimp dolphin dolphin-plugins spectacle ffmpeg kbackup kcron kapman kdialog konsole zip unzip unrar openssh kdegraphics-thumbnailers ffmpegthumbs feh postgresql gcc packagekit-qt5 keepassxc gwenview kwrite code git python-pip x11-ssh-askpass ufw vim



# UPDATE mkinitcpio.conf MODULES and HOOKS
sed -i "s/^MODULES=()/MODULES=($MODULES_LIST)/" /etc/mkinitcpio.conf
sed -i "s/^HOOKS=(.*)$/HOOKS=($HOOKS_LIST)/" /etc/mkinitcpio.conf

# generate it
mkinitcpio -p linux



# INSTALL, EDIT AND GENERATE GRUB
########################

# install grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# edit GRUB_CMDLINE_LINUX_DEFAULT
CMDLINE_DEFAULTS="cryptdevice=UUID=$LVM_UUID:cryptlvm root=/dev/volumees/root resume=/dev/volumees/swap"

if [ "$COMPUTER" = 'desktop' ]; then
    EXTRA_PACKAGES="xf86-video-amdgpu amd-ucode vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver"
    CMDLINE_DEFAULTS="$CMDLINE_DEFAULTS radeon.cik_support=0 amdgpu.cik_support=1 radeon.si_support=0 amdgpu.si_support=1"
else
    EXTRA_PACKAGES="xf86-video-intel intel-ucode"
    CMDLINE_DEFAULTS="$CMDLINE_DEFAULTS l1tf=full,force mds=full,nosmt mitigations=auto,nosmt nosmt=force"  # intel security fix
fi

# edit GRUB_CMDLINE_LINUX_DEFAULTS in /etc/default/grub
sed -i -E "s,GRUB_CMDLINE_LINUX_DEFAULT=\"(.*)\",GRUB_CMDLINE_LINUX_DEFAULT=\"$CMDLINE_DEFAULTS\"," /etc/default/grub

# extra packages
print_line "Installing extra packages for the $COMPUTER computer, before generating GRUB..."
pacman -S --noconfirm $EXTRA_PACKAGES

# generate grub
grub-mkconfig -o /boot/grub/grub.cfg


# MY CUSTOM LINES
#################

# blacklist the radeon driver
echo 'blacklist radeon' >> /etc/modprobe.d/blacklist.conf

# set VIM as default editor
echo -e 'EDITOR=vim' >> /etc/environment



# SECURITY STEPS examples
#########################

# change "umask 022" to "umask 077"
sed -i "s/umask 022/umask 077/" /etc/profile

# set "PermitRootLogin" of SSH to "no"
sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config

# set "PasswordAuthentication" of SSH to no"
sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config

# ufw rules
# example syntax: ufw allow (out|in) (log) proto (tcp|udp) (from (any|ip)|to (any|ip)) port (ssh|22)
# print_line "Setting UFW rules..."
# . ./installer/modules/ufw.sh



# GENERATE SSH AND SET APPROPRIATE SETTINGS
###########################################

# set directory path
SSH_DIR="$HOME_DIR/.ssh"

# create directory
mkdir -p "$SSH_DIR"

# generate ssh-keygen
ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/id_rsa"

# copy authorized_keys so it can remember us
cp /installer/authorized_keys "$SSH_DIR"

# set permissions for ~/.ssh
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"
chmod 600 "$SSH_DIR/id_rsa"
chmod 644 "$SSH_DIR/id_rsa.pub"
chmod 700 "$SSH_DIR"
chattr +i "$SSH_DIR"



# SYSTEM SERVICES
#################
USER_SYSTEMD="/home/$USERNAME/.config/systemd/user"

# enable network services
systemctl enable NetworkManager

# enable sddm display manager for KDE Plasma
systemctl enable sddm

# enable ssh-agent so it asks for your passphrase only once
ln -s "$USER_SYSTEMD/ssh-agent.service" "$USER_SYSTEMD/default.target.wants/ssh-agent.service"
