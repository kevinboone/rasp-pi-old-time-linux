#!/bin/bash

. ./BUILDCONFIG.sh
. ./CONFIG.sh

ESSENTIAL_PKGS="bash ncurses-base libtinfo6 sysvinit-core sudo coreutils strace libpam-runtime util-linux login console-data kbd hostname file kmod procps grep findutils psmisc sed console-tools console-data console-setup console-setup-linux gzip ncurses-bin libpcre3 ca-certificates apt apt-utils libc-bin diffutils"

PKGS_NON_FREE=""

# ========= Work out what to install ============

MODULES=""

PKGS_MAIN="$ESSENTIAL_PKGS $OPTIONAL_PKGS"

if [[ $INSTALL_MEDIA == 1 ]]; then
  PKGS_MAIN="$PKGS_MAIN vlc"
  INSTALL_ALSA=1
fi

if [[ $INSTALL_NET_WIFI == 1 ]]; then
  PKGS_NON_FREE="$PKGS_NON_FREE firmware-brcm80211"
  INSTALL_NET_UTILS=1 
fi

if [[ $INSTALL_NET_UTILS == 1 ]]; then
  PKGS_MAIN="$PKGS_MAIN net-tools iputils-ping ifupdown dhcpcd dhcpcd5 curl dnsutils rsync ftp telnet"
fi

if [[ $INSTALL_NET_WIFI == 1 ]]; then
  #PKGS="$PKGS iw wpasupplicant wireless-regdb crda"
  PKGS_MAIN="$PKGS_MAIN iw wpasupplicant"
fi

if [[ $INSTALL_ALSA == 1 ]]; then
  PKGS_MAIN="$PKGS_MAIN alsa-utils libasound2"
fi

if [[ $INSTALL_X == 1 ]]; then
  PKGS_MAIN="$PKGS_MAIN xorg xserver-xorg-input-evdev twm twm openbox x11-xserver-utils feh libglib2.0-0"
  MODULES="$MODULES evdev"
fi

PKGS_MAIN="$PKGS_MAIN $OPTIONAL_PKGS"

MODULES="$MODULES $OPTIONAL_MODULES"

# ============ Start build here =================

mkdir -p $BOOT 
mkdir -p $ROOTFS 

echo "Cleaning work area"

rm -rf $ROOTFS/*
rm -rf $BOOT/*

# ============ Download boot firmware =================

if [ -f "$TMP/firmware.zip" ]; then
  echo "Using cached firmware" ;
else
  echo "Downloading firmware"
  curl -o $TMP/firmware.zip \
     https://codeload.github.com/raspberrypi/firmware/zip/refs/heads/master
fi

# ============ Unpack firmware =================

echo "Unpacking firmware" ;
(cd $TMP; unzip -q $TMP/firmware.zip)

cp -aux $TMP/firmware-master/boot/* $BOOT/

mkdir -p $ROOTFS/lib/modules
cp -aux $TMP/firmware-master/modules/* $ROOTFS/lib/modules/

rm -rf $TMP/firmware-master/

# ===== Export env vars used by get_deb.pl =======

export ROOTFS 
export BOOT 
export TMP
export RASPBIAN_RELEASE

# ============ Download packages =================

rm packages.lst

echo "Downloading main packages" ;
GROUP=main ./get_deb.pl $PKGS_MAIN

if [ -n "$PKGS_NON_FREE" ]; then 
  echo "Downloading non-free packages" ;
  GROUP=non-free ./get_deb.pl $PKGS_NON_FREE
fi

mv packages.lst rootfs-overlay/etc/dpkg/status

# ======== Add local config and binaries  ========

echo "Adding local configuration"

# Remove anything from /var and /run that was 
#  installed by the package installer. /var will be on a memory
#  filesystem in this implementation. We have to remove
#  the existing contents so we can replace it with a
#  symlink.

rm -rf $ROOTFS/var
rm -rf $ROOTFS/run
rm -rf $ROOTFS/tmp
mkdir $ROOTFS/tmp
cp -ax contrib-bin/* $ROOTFS
cp -ax rootfs-overlay/* $ROOTFS
cp CONFIG.sh $ROOTFS/etc
# Make bash available as /bin/sh
(cd $ROOTFS; ln -sfr bin/bash bin/sh)
(cd $ROOTFS; ln -sfr usr/bin/vim.basic bin/vi)

if [[ $INSTALL_NET_WIFI == 1 ]]; then
  (cd $ROOTFS/etc/; ln -sfr init.d/dhcpcd rc1.d/S25dhcpcd;  ln -sfr init.d/wpa_supplicant rc1.d/S10wpasupplicant; ln -sfr init.d/wifi rc1.d/S20wifi; ln -sfr init.d/dhcpcd rc1.d/S25dhcpcd; ln -sfr init.d/onetime_datetime rc1.d/S30onetime_datetime; ln -sfr init.d/sshd rc1.d/S40sshd; ) 
fi

if [[ $INSTALL_ALSA == 1 ]]; then
  (cd $ROOTFS/etc/; ln -sfr init.d/audio rc1.d/S80audio) 
fi

if [[ $INSTALL_X == 1 ]]; then
 (cd $ROOTFS; ln -sfr usr/bin/vim.basic bin/vi)
fi

sed --in-place -e "s/MODULES/$MODULES/" $ROOTFS/etc/rc.d/startup.sh

update-mime-database /tmp/rootfs/usr/share/mime/

# ======== Make essential directories =============

mkdir -p $ROOTFS/dev
mkdir -p $ROOTFS/sys
mkdir -p $ROOTFS/proc

# Remove the "home" directory that seems to sneak in
#  from one of the previous steps
rm -rf $ROOTFS/home
ln -sfr /mnt/usb0/home $ROOTFS/home

#(cd $ROOTFS; ln -sfr bin/dash bin/init)

# =============== Set an SSH host key ===============

ssh-keygen -N "" -f $ROOTFS/etc/ssh/ssh_host_rsa_key

# =============== Set hostname ======================

echo $HOSTNAME > $ROOTFS/etc/hostname
sed --in-place -e "s/XXX/$HOSTNAME/" $ROOTFS/etc/hosts

# =============== Clean up the root filesystem ======

rm -rf $ROOTFS/usr/share/doc
rm -rf $ROOTFS/lib/runit-helper
rm -rf $ROOTFS/lib/ifupdown
rm -rf $ROOTFS/lib/systemd
rm -rf $ROOTFS/lib/udev

echo "Done. Now create the disk image using sudo ./makeimg.sh"

