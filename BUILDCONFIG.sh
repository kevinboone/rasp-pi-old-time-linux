# This is the main configuration files for rasp-pi-min-desktop-build. It
#   controls the build process, and is also copied into the image where
#   it will also be used to provide settings at run-time.

# RASPBIAN_RELEASE identifies the Raspbian repository that will be used
#  to obtain the binaries used by this build process. Possibilities are
#  jessie, buster, bullseye, etc. Note that "bookworm", the latest,
# is a little unstable at the time of writing.
RASPBIAN_RELEASE=bookworm

# Location for general temporary files. Any that are not deleted after
#  the build and installation can be removed using cleanall.sh. Note, 
#  however, that subsequent builds will be much faster if these files
#  are left in place.
TMP=/tmp

# Where to put the root FS and the boot directory, as they are generated
#  by the build process. These directories will be created. They need
#  to be in a place where they can be written by an unprivileged used.
#  These directories are left after the build, so that copy-to-card.sh
#  can use them to populate the SD card. To clean up completely, use
#  cleanall.sh
BOOT=$TMP/boot
ROOTFS=$TMP/rootfs

# The disk image that will be generated
IMG=$TMP/pi.img

# The default hostname of the system to be built. This appears at the command
#  prompt, but isn't of much greater significance in this kind of installation.
# At runtime, the hostname will be read from /etc/hostname, which will be
#  writeable.
HOSTNAME=console

# A list of optional packages to install (the essential packages are
#   defined in build.sh, and will depend on what optional components
#   are selected).
OPTIONAL_PKGS="openssh-client openssh-server vim"

# You can include web browser, etc., if required.
#OPTIONAL_PKGS="openssh-client openssh-server vim firefox-esr thunar obconf"

# Specify additional modules to load. For example, cdc-acm is the driver
#  for USB-serial devices. This list should be separated by spaces.
OPTIONAL_MODULES="cdc-acm"

# Decide whether to install network utilities like ifconfig. This is
#  implied by INSTALL_NET_WIFI. If INSTALL_NET_UTILS=0, then the
#  startup will still try to configure the built-in ethernet adapter
#  using DHCP, unless it is disable in firmware.
INSTALL_NET_UTILS=1

# Install Wifi support. This will include the start-up scripts, and also
#  utilties like iwconfig
INSTALL_NET_WIFI=1

# Install ALSA audio utilties and enable the audio set-up scripts.
INSTALL_ALSA=1

# Install VLC media player
INSTALL_MEDIA=1

# Enable X support. This will install a _lot_ of software, and 
#  it's still nowhere near enough for a practical X destkop. You might need
#  to hack on rootfs-overlay/etc/X11/X.conf to configure input devices.
#  Start an X session by running /usr/bin/startx.sh as root
INSTALL_X=1

