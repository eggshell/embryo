#!/usr/bin/env bash
# Written by eggshell, esc, wuputah
# 2016-12-20

set -e

# Turn comments into literals, including output during execution.
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

function check_internet() {
  reporter "Confirming internet connection"

  if [[ ! $(curl -Is http://www.google.com/ | head -n 1) =~ "200 OK" ]]; then
    echo "Your Internet seems broken. Press Ctrl-C to abort or enter to continue."
    read
  else
    echo "Connection successful"
  fi
}

function partition_drive() {
  reporter "Making 2 partitions -- boot and root -- on ssd"
  parted -s /dev/${1} mktable msdos
  parted -s /dev/${1} mkpart primary 0% 100m
  parted -s /dev/${1} mkpart primary 100m 100%
}

function make_filesystems() {
  reporter "Making filesystems"
  DISK="${1}"
  PART1="${DISK}1"
  PART2="${DISK}2"
  mkfs.ext2 /dev/${PART1}  # /boot
  mkfs.btrfs -f /dev/${PART2} # /

  reporter "Setting up /mnt"
  mount /dev/${PART2} /mnt
  mkdir /mnt/boot
  mount /dev/${PART1} /mnt/boot
}

function rank_mirrors () {
  reporter "Ranking pacman mirrors"
  mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
  rankmirrors -n 6 /etc/pacman.d/mirrorlist.orig > /etc/pacman.d/mirrorlist
  pacman -Syy
}

function install_packages() {
  reporter "Installing base packages"
  pacstrap /mnt base base-devel

  reporter "Installing system"
  arch-chroot /mnt pacman --noconfirm -S                 \
    alsa-firmware alsa-utils alsa-plugins                \
    pulseaudio pulseaudio-alsa pavucontrol               \
    xorg-xinit xorg-server xorg-server-devel xorg-xrdb   \
    i3-wm i3lock i3status dmenu                          \
    ttf-dejavu ttf-freefont ttf-arphic-uming ttf-baekmuk \
    openssh git rxvt-unicode firefox xscreensaver        \
    redshift syslinux
}

function install_mirrorlist() {
  reporter "Installing new ranked mirror list"
  cp /etc/pacman.d/mirrorlist* /mnt/etc/pacman.d
}

function make_fstab() {
  reporter "Generating fstab"
  genfstab -p /mnt >> /mnt/etc/fstab
}

function finalize_installation() {
  HOSTNAME=$1

  reporter "Chroot-ing into /mnt"
  arch-chroot /mnt /bin/bash << END_OF_CHROOT

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
  echo "${HOSTNAME}" > /etc/hostname

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
  sed 's/root=.*/root=\/dev\/sda2 ro/' < /boot/syslinux/syslinux.cfg > /boot/syslinux/syslinux.cfg.new
  mv /boot/syslinux/syslinux.cfg.new /boot/syslinux/syslinux.cfg

  reporter "Setting initial password to \"root\""
  echo root:root | chpasswd

# end section sent to chroot
END_OF_CHROOT

  # unmount
  umount /mnt/{boot,}
}

function main() {
  if [[ $# -ne 2 ]]; then
    echo "$0: usage: archlinux-install.sh <disk-name> <hostname>"
  fi

  DRIVE=$1
  HOSTNAME=$2

  check_internet
  partition_drive $DRIVE
  make_filesystems $DRIVE
  rank_mirrors
  install_packages
  install_mirrorlist
  make_fstab
  finalize_installation $HOSTNAME
  echo "Done! Unmount the CD image from the system, then type 'reboot'."
}

main "$@"
