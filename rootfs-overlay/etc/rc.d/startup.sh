#!/bin/bash
# This is the main start-up file for pi-retro-linux. Note that this
# file cannot be edited on the Pi at runtime, even though there is a
# read-write overlay over the /etc directory. That's because the overlay
# does not exist until this file creates it, and by that time this file
# is already loaded.

echo Preparing filesystems...

mount /proc
mount /sys
mount /tmp
mkdir /dev/pts
mount /dev/pts

echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

mkdir /tmp/var
mkdir /tmp/run
mkdir /var/lib
mkdir -p /var/log
touch /tmp/resolv.conf

echo Loading modules...

/bin/load-modules.sh MODULES

echo Setting permissions... 

chmod 660 /dev/ttyAMA0

echo Starting logging... 

syslogd
dmesg --console-level 2

mount /mnt/usb0
while ! grep -q -s /dev/sda1 /proc/mounts; do
  echo Waiting for USB storage to mount...
  sleep 1
  mount /mnt/usb0
done

echo Setting up filesystem overlays...

mkdir -p /mnt/usb0/home
mkdir -p /mnt/usb0/overlay
mkdir -p /mnt/usb0/overlay/etc
mkdir -p /mnt/usb0/overlay/work

mount -t overlay -o workdir=/mnt/usb0/overlay/work,upperdir=/mnt/usb0/overlay/etc,lowerdir=/etc overlay /etc

# Don't read the config file until the /etc/ overlay is in place -- it
#  might be different in the overlay
. /etc/CONFIG.sh

mkdir -p /var/cache/apt/archives/partial
mkdir -p /mnt/usb0/overlay/etc/dpkg
ln -sfr /etc/dpkg /var/lib/

echo Setting up loopback interface...

hostname --file /etc/hostname
ifup lo

echo Setting up console... 

loadkeys $CONSOLE_KEYS
setfont -C /dev/tty1 $CONSOLE_FONT
setfont -C /dev/tty2 $CONSOLE_FONT
setfont -C /dev/tty3 $CONSOLE_FONT

#chvt 2

