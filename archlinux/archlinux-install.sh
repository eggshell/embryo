#!/usr/bin/env bash
# Written by eggshell, esc, wuputah
# 2016-12-20

set -e

## Turn comments into literal programming, including output during execution.
function reporter() {
  message="$1"
  shift
  echo
  echo "${message}"
  for (( i=0; i<${#message}; i++ )); do
      echo -n '-'
  done
  echo
}

reporter "Confirming internet connection"
if [[ ! $(curl -Is http://www.google.com/ | head -n 1) =~ "200 OK" ]]; then
  echo "Your Internet seems broken. Press Ctrl-C to abort or enter to continue."
  read
else
  echo "Connection successful"
fi

reporter "Making 2 partitions -- boot and root -- on ssd"
parted -s /dev/sdc mktable msdos
parted -s /dev/sdc mkpart primary 0% 100m
parted -s /dev/sdc mkpart primary 100m 100%

reporter "Making filesystems"
mkfs.ext2 /dev/sdc1  # /boot
mkfs.btrfs /dev/sdc2 # /

reporter "Setting up /mnt"
mount /dev/sdc2 /mnt
mkdir /mnt/boot
mount /dev/sdc1 /mnt/boot

reporter "Ranking pacman mirrors"
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
rankmirrors -n 6 /etc/pacman.d/mirrorlist.orig > /etc/pacman.d/mirrorlist
pacman -Syy

reporter "Installing base packages"
pacstrap /mnt base base-devel

reporter "Installing system"
arch-chroot /mnt pacman --no-confirm -S  \
  alsa-firmware alsa-utils alsa-plugins  \
  i3 dmenu xorg xorg-init xterm          \
  openssh                                \
  python2 python2-setuptools python2-pip \
  syslinux

reporter "Installing new ranked mirror list"
cp /etc/pacman.d/mirrorlist* /mnt/etc/pacman.d

reporter "Generating fstab"
genfstab -p /mnt >> /mnt/etc/fstab

reporter "Chroot-ing into /mnt"
arch-chroot /mnt /bin/bash << END_OF_CHROOT

## Turn comments into literal programming, including output during execution.
function reporter() {
  message="$1"
  shift
  echo
  echo "${message}"
  for (( i=0; i<${#message}; i++ )); do
      echo -n '-'
  done
  echo
}

reporter "Setting initial hostname"
echo "eggcrate" > /etc/hostname

reporter "Setting timezone to US Central"
ln -s /usr/share/zoneinfo/America/Chicago /etc/localtime

reporter "Setting locale"
locale > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US ISO-8859-1" >> /etc/locale.gen
locale-gen

reporter "Creating initial ramdisk environment"
mkinitcpio -p linux

reporter "Installing syslinux bootloader"
syslinux-install_update -i -a -m

reporter "Updating syslinux config with correct root disk"
sed 's/root=.*/root=\/dev\/sdc2 ro/' < /boot/syslinux/syslinux.cfg > /boot/syslinux/syslinux.cfg.new
mv /boot/syslinux/syslinux.cfg.new /boot/syslinux/syslinux.cfg

reporter "Setting initial password to \"root\""
echo root:root | chpasswd

# end section sent to chroot
END_OF_CHROOT

# unmount
umount /mnt/{boot,}

echo "Done! Unmount the CD image from the system, then type 'reboot'."
