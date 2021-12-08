# "Old Time Linux" for the Raspberry Pi 

Kevin Boone, December 2021

This is a collection of shell and Perl scripts that build a minimal-ish,
mostly-read-only installation of Linux on an SD card, ready for use in a
Raspberry Pi. It's like the kind of Linux we had in the mid-90s, where an
entire distribution was a shoe-box full of floppy disks. Configuration requires
command-line tools and hacking on a variety of poorly-documented text files.
Back in the day when we had no CPU or memory to spare, we couldn't waste
precious resources on auto-mounters or integrated desktops. The result was a
compact, and comparatively fast Linux, with nothing wasted. On a Pi 3B+, the
installation boots to a console in about four seconds, and to an X session (if
required) in a further five seconds.

Unlike some of my Raspberry Pi image-building tools, this one is not really
intended for embedded use. Instead, it is designed to produce a minimal desktop
computer, capable of running X applications.  As such, it expects a USB flash
drive to be installed, which will be used for home directories and a read-write
overlay for the `/etc` directory.  This flash drive needs to have at least one
`ext4` partition, which will be populated with the necessary directories at
first boot.

This approach allows for some basic run-time configuration (adding users,
changing the wifi network settings, etc), while still keeping the system
read-only enough that it doesn't need a shut-down procedure.

This tool should produce an image that will work with any Pi, but I've mostly
tested with the 3B+. It isn't a small image -- what's "minimal" about this is
the number of processes that will start at boot time. There's no systemd,
D-Bus, Udev, PulseAudio, etc.  I'm aiming for a boot time of only a few
seconds, measured from the time the kernel starts, and a few more seconds to
get an X desktop on the screen.

This is not a complete Linux and it certainly isn't a Linux distribution -- it
is intended as a base for customization. The actual binaries are drawn from the
standard Raspbian repositories. There's no simple way to add software to the
installation once the image has been built, as the root filesystem is
read-only. It's easy enough to add software packages at build time, however,
and the build process should take care of fetching the dependencies. It's not
actually _impossible_ to add software at runtime, but it isn't encouraged --
see below.

The basic installation boots to a console, and there is initially only one
user, `root` (password "toor"). You can create new users using the `useradd`
command. To start an X session, run `startx`.

## Rationale

Why another Raspberry Pi Linux installation? There are many desktop
implementations, some of them much lighter than Raspbian.  There are also
embedded Linux distributions for the Pi, like Tiny Core. Still, all the desktop
Linux implementations for the Pi that I know about remain rather hefty. They
all use systemd, D-Bus, UDev, PulseAudio, etc. This project seeks to get away
from all that, and implement a version of Linux that runs nothing but a kernel
and the barest minimum of services. It's something between an embedded Linux
and a desktop Linux. 

My objective, really, is to find out whether it's even _possible_ to run a
desktop Linux without all the contemporary bloat and complexity.  All the
unnecesssary software in a modern Linux is a consumer of resources, which means
it's a consumer of energy. If we are to avoid a climate catastrophe, we should
be thinking about whether we need to waste energy just to avoid having to hack
on a configuration file or two.

## Requirements

- A Linux workstation, to build the Pi boot image. It should have the usual file manipulation utilities, but particularly xzdec for unpacking some Raspbian packages.
- A Raspberry Pi -- any version, but I'm mostly testing on the 3B+.
- A USB flash drive for the Pi, with at least one partition formatted as `ext4`.

## Build procedure

Edit `BUILDCONFIG.sh` to determine what is to be installed, and any other
settings that need to be edited. Edit `CONFIG.sh` to change default run-time
settings. This file is copied to `/etc/` in the root filesystem during build,
and is read by various start-up scripts when the Pi boots.

    $ ./build.sh
    # ./makeimg.sh
    # dd if=/tmp/pi.img of=/dev/sdcard bs=128M

`build.sh` downloads the Pi firmware and Linux software, and populates
`/tmp/boot` and `/tmp/rootfs`. `makeimg.sh`, which will usually need to be run
as `root`, creates the image `pi.img`, which can then be copied to an SD card,
or otherwise tested.

The script `cleanall.sh` removes everything created during the build,
apart from the image file `pi.img`. 

## Read-only Linux on the Pi

Why would you want a (mostly) read-only Linux, anyway? For embedded and kiosk
applications, users won't follow a shut-down procedure -- it might not even be
possible to. But even in a desktop Linux, it's generally safer if the
user can just pull the plug. A desktop Linux can't be made
_completely_ read-only -- it wouldn't even be possible to change
wifi network settings except at the command line in every session.
Similarly, it's useful to be able to do basic user configuration. And, 
of course, we assume that the user will do some work, and need somewhere
to store the files that are worked on. Conventionally, these will
be in a home directory.

If we could make the entire installation read-only, problems of breaking
configuration changes and disorderly shutdown would be completely obviated. If
nothing is writeable, nothing can be left in a broken state if the user just
pulls the plug. My strategy with this project is to create a _mostly_ read-only
system. The root filesystem is read-only, and we use a USB flash drive for home
directories, and for read-write overlays for those parts of the root filesystem
that really can't be read-only.  By mounting the flash drive in synchronous
mode, problems of disorderly shutdown are mostly avoided. Problems of breaking
configuration changes can be resolved simply by erasing the <code>/etc</code>
overlay from the flash drive on another computer (or fixing the changes, if
they can be determined). 

Raspbian and similar distributions are not at all designed to run in a
read-only environment. In fact, it takes a lot of effort to make read-only
operation possible with any modern Linux.  Most obviously, there has to be a
`/tmp` directory that can hold temporary files. Many utilities expect to be
able to write to `/var`, `/run` and other places. My approach is to define
`/tmp` to be an in-memory filesystem using `tmpfs`; all other directories that
have to be writable -- but not persistent -- are symbolic links to directories
under `/tmp`. Utilities that change configuration at runtime -- such as
`dhcpcd` when it configures a network interface -- have to be provided with
ways to overwrite configuration files (like `/etc/resolv.conf`) that are on a
read-only filesystem. This is where the overlays come in. 

For desktop-type operation the situation is even more complicated, because
modern Linux distributions scatter read-write and read-only files throughout
the root directory structure, assuming that everything is writeable.  For
example, Ubuntu-like distributions have `/var/run`, which contains mostly
ephemeral files and `/var/lib', which mostly contains persistent files,
side-by-side in `/var`. To some extent I've gotten around that problem by
making some of the `/var` subdirectories links to `/etc/`, which will be
writeable.

## Basic operation

Old Time Linux boots to a console. If you want to run X, start an X session
using `startx`. You'll need to provide a user `.xsession` file, containing
applications to run when X starts -- just as we did in the 90s.

No users other than `root` are defined start-up. The password for `root` is
`toor` (this can be changed using `passwd`, as usual). The usual `useradd`,
etc., should work. Note that any changes made to configuration files in `/etc/`
actually end up in (read-write) `/mnt/usb0/overlay/etc`.

To shut down, just switch off.

## Living without auto-configuration

To get the fastest possible boot to a working (console) interface, _nothing_ is
auto-configured, beyond the facilities provided by the kernel. There's no UDev
no D-Bus, etc. The installation script knows what needs to be done for common
peripherals like USB storage. However, for anything complicated you'll need (as
a minimum) to specify what kernel modules need to be loaded.  There's no easy
way to figure this out, except by looking on a conventional Raspberry Pi
desktop system, to see what modules are actually loaded when particular
peripherals are plugged in.

This is not a defect -- it is a feature. Auto-configuration is great for
high-poweded, integrated desktop systems, but it completely defeats the purpose
of this project. Of course, to operate a Linux system without
auto-configuration, you really have to know what you're doing.

## Wifi networking 

If wifi networking is enabled in the configuration file, the build will include
networking utilities, device firmware, and scripts to configure the network
adapters using DHCP.  The configuration will need to include the details of the
access point and a password, if used. Enabling networking also enables the SSHD
server for remote login.  Starting a Wifi network can take a little while, but
this doesn't delay getting to a console, since it's done in the background.

Wifi configuration is read from `/etc/CONFIG.sh`, which is only read at boot
time. This file is in `/etc` and so is writable (provided a USB flash drive is
inserted). So a simple way to change the network configuration is just to edit
this file and reboot. Or you can use the command-line utility `wpa\_cli`. For
example:

    # wpa_cli scan
    (wait a few seconds)

    # wpa_cli scan_results
    (see a list of available wifi access points with their SSIDs)

    # wpa_cli -i wlan0 add_network 
    # wpa_cli -i wlan0 set_network 0 ssid MY_SSID
    # wpa_cli -i wlan0 set_network 0 psk MY_PASSWORD
    # wpa_cli -i wlan0 enable_network 0 

The Raspberry Pi has no real-time clock. If networking is enabled, the time is
set using a simple script that gets its from one of Google's webservers. This
isn't a very robust approach, but it works for simple applications.

## Boot process

The Linux start-up process uses `init`. It goes without saying that there's no
place for systemd here. Most of the initialization is done in a single script
`/etc/rc.d/startup.sh`. There is no meaningful notion of "run level" here --
technically everything operates at run level 1. So `init` will run subsidiary
start-up scripts in `/etc/rc1.d`, in alphanumeric order. Of course you can add
new scripts for additional configuration, either before building the image, or
at runtime.  As in a conventional (pre-systemd) Linux, the scripts in
`/etc/rc1.d` are actually symlinks to scripts in `/etc/init.d`. The links have
conventional names of the form `SNNsomething`, where the NN is a two-digit
number indicating the start order. There are no corresponding `Kxxsomething`
scripts for shutting down, because shutting down amounts to powering off. 

The scripts in `/etc/init.d` are always included in the build; if a feature is
enabled in `BUILDCONFIG.sh` that usually means that the corresponding symlink
to `/etc/rc1.d` gets created in the build.  Otherwise there is no symlink, and
the script will not be run.

## Virtual consoles

The `inittab` file puts `getty` processes on virtual consoles 1-3, so these are
the ones than can be logged in. The kernel's command line has
`console=/dev/tty4`, which puts the system console on console 4. This is where
kernel log messages end up. 

## USB storage

Old Time Linux requires a USB flash drive connected to the Raspberry Pi, and it
should be the only USB storage connected when the Pi boots -- the system isn't
smart enough to figure out which one to use, if more than one USB storage
device is installed.

The first partition in the USB flash will be mounted on `/mnt/usb0`.  The boot
process will wait (perhaps forever) until this device is available -- it's a
crucial part of the system, and there's no point booting without it.

The default set-up uses the `sync` option in the mount, so that there's less
chance that the USB storage will be corrupted when powering off.  This makes
storage writes less responsive but, on the plus side, when it looks like a file
has been saved, it's really been saved -- it's not just lurking in a buffer
somewhere.

The USB flash drive has two main functions -- user home directories, and an
overlay for those parts of the root filesystem that have to be read-write. 

## Audio

If `ENABLE\_AUDIO=1` in `BUILDCONFIG.sh`, the build will include basic ALSA
utilities. More importantly, though, it will load the kernel's audio drivers,
and set the permissions appropriately on `/dev/snd`. A few sample sounds are
included in `/usr/share/sounds`.

Almost all mainstream Linux distributions use PulseAudio for audio processing
and routing. I do understand the problem that PulseAudio was supposed to solve
but, frankly, I can't think of any need for it in most desktop applications.
It's one of those things that is only viable because most modern computers are
so over-resourced. A few people might actually need it and, for those who
don't, the resource drain is unlikely to be noticed in a modern machine. Good
old ALSA is sufficient for Old Time Linux.

If you're using an HDMI monitor then most likely HDMI audio will be ALSA device
0, and the audio jack will be device 1. So to play audio through the jack, you
could test with

    aplay -D hw:1 ...

To get a list of known audio devices, do `aplay -L`.

The basic build does not include any particular audio players apart from basic
ASLA utilities. If you want anything else (`vlc`, `mplayer`), you can add
enable the package(s) to `OPTIONAL\_PKGS` in `BUILDCONFIG.sh`.

## Official touch-screen support

There's nothing special to do to enable the display part of the Pi official
touch-screen -- support is built into firmware. However, to enable the touch
sensitivity and the backlight control, you'll need to enable kernel modules
`rpi-ft5406` and `rpi\_backlight` respectively. You can just add these to
`OPTIONAL\_MODULES`. For the record, the backlight brightness is set in the
range 0-255 by writing `/sys/class/backlight/rpi\_backlight/brightness`. 

## Optional kernel modules

There is no device detection -- any kernel modules you'll need will have to be
loaded at boot time. There is a setting `OPTIONAL\_MODULES` for this in
`BUILDCONFIG.sh`.  Modules specified here are loaded very early in the boot
process -- before showing a prompt. So if you're using modules that are slow to
load, or might even fail to load, it would be better to create an additional
script under `rc1.d` and do the load there. This part of the
filesystem is writeable.

## X support

If you set `INSTALL\_X=1` in `BUILDCONFIG.sh`, the installer will download and
install a minimal set of software to run X, including a couple of basic window
managers (`twm` and `OpenBox`). It is at this point, however, that we realize
how much Udev and D-Bus do for us in a regular, desktop Linux -- here we have
to hack on the X11 configuration file manually to add all the input devices and
screen settings.  Of course, this is the Old Time way.  The sample file at
`rootfs-overlay/etc/X11/X.conf` should work for a system with a single USB
keyboard, a single USB mouse, and a single monitor. However, I can't _promise_
that it works in any set-up but my own. Those of us who used Linux back in the
90s have not-very-fond memories of hacking on X server configuration files.
Fortunately, HDMI does not require us to undertake the awful process of
specifying display scan timings explicitly in a configuration file.

The boot process will look the module `evdev`, which is required for the X
server to use the mouse and keyboard devices in `/dev/input`.

To start an X session run `startx`. This will start the X server, and run the
user's <code>.xsession</code> file. A suitable
file might contain

    x-terminal-emulator &
    openbox  

This installation is at best a starting point for running an X-based
installation, and will need extensive customization for anything practical. 

## Console permissions

There is a problem here, because all the devices in `/dev/` that the user might
want to interact with will, by default, be owned by `root`. This includes the
input devices, framebuffer (used by the X server), audio devices, and other
things. In a modern desktop Linux, setting permissions is handled by the
combination of systemd and UDev. We need a better -- sorry, simpler --
solution. 

When the user logs in, the shell will be initialized by executing
`/etc/profile`.  A line in this file executes a script called
`console-setup.sh`, which will change the ownership of all the necessary
devices.

Of course, `profile` is executed as an ordinary user, not `root`, so we'll need
to use `sudo` to run the script. So in `/etc/profile` we actually have:

    sudo /usr/bin/console-setup.sh

In order not to get prompted by `sudo`, we'll need to configure the
`/etc/sudoers` file like this:

    ALL     ALL=NOPASSWD:   /usr/bin/console-setup.sh

It should be obvious that this simple configuration would allow different users
in a multi-user system to irritate one another by fiddling with their device
permissions. However, we aren't really contemplating a multi-user system here.

## Bluetooth and serial UART

The default installation disables Bluetooth, and enables the serial UART (pins
8 and 10) as device `/dev/ttyAMA0`. I don't use Bluetooth, but I do sometimes
use the serial UART. In addition, disabling Bluetooth makes the boot about a
half-second faster. 

To restore the default functionality, remove the `dtoverlay=pi3-disable-bt`
line from `bootfiles/config.txt`. 

## The build process

Here is what `build.sh` does.

1. Downloads the latest Pi firmware/kernel bundle, and unpacks it into a
directory that will become the boot partition of the SD card.

2. Merges into the boot directory the content of the <code>bootfiles/<code>
directory. This is the place to set specific firmware and kernel parameters.

3. Downloads all the packages that are needed according to the configured
options, along with all their dependencies. These all go into a directory
that will become the root filesystem on the SD card. 

4. Merges with this directory the contents of `contrib-binaries`.

5. Merges the contents of `overlay-rootfs`, substituting
placeholders in some configuration files for values in `BUILDCONFIG.sh`.

6. Copies `CONFIG.sh` itself into the generated `/etc`
directory, where it will be read at runtime by a number of scripts.

7. Creates link from scripts in `/etc/init.d` to `/etc/rc1.d`, so that
`init` will run them when booting.

8. Updates the MIME database in `/usr/share/mime` according to
which packages were installed. This gets done dynamically in a real
desktop installation, but that's not poossible with a read-only installation. 

9. Generates a public/private key paid for the SSH daemon. 

Note that the build process, by default, uses the "bookworm" Debian
release, which is (at the time of writing) not considered production-ready.
 
## Bundle contents

`contrib-binaries/` -- this directory contains pre-compiled binaries of
utilities that are not available in the Raspbian repository -- probably
because I wrote them. For example, this build uses a minimal version of
`syslogd` that is designed for use with  a temporary logfile in memory.
(see https://github.com/kevinboone/syslogd-lite for more information).
This directory is structured as it will appear in the root filesystem.

`rootfs-overlay/` -- files that will overwrite versions that are downloaded
from repositories. These files contain configuration specific for this
build. Some files might need to be edited, but it's difficult to
document every conceivable change. 

`bootfiles/` -- additional files that will be copied to the boot partition of
the card (e.g., cmdline.txt). The defaults should work, but it's not unusual to
have to change these files to, for example, enable specific features in
firmware. These are standard Raspberry Pi files that are well documented.

`misc-config` -- various configuration files that could not be placed
in `rootfs-overlay` because their target directories are generated
during the build.

## Installing new packages

The Old-Time Linux installation is intended to be read-only, apart from user
home directories, and parts of the root filesystem that really have to be
writeable. It is possible, however, to add new packages at runtime. It's not
encouraged, however, because it defeats the purpose of this kind of
installaion, and the implementation is incomplete.

If you really have to add new software, however, here's the process.

1. Remount the root partition read-write

    # mount -o rw,remount /

2. Update the CA certificates (this could take a while).

    # update-ca-certificates

3. Try to run `apt-get update`. It will fail, with an error message of the form "public key not available [number]"

4. Add the missing public key

    # apt-key adv --keyserver keyserver.ubuntu.com --recv-keys [number]

5. Repeat `apt-get update`

6. Use `apt-get install [package]` as usual.

7. Remount the root filesystem read-only

    # mount -o ro,remount /

There are all sorts of reasons why this process might not work as expected.  In
particular, the `/etc/` and `/usr` directories are updated, but these
directories are stored in different places (`/etc/` is an overlay).  It's
rather easy for these directories to get out of sync, and leave everything in a
mess. Also, be aware that incoming packages are buffered in memory -- so
there's a limit to how much can be installed in one operation.

## Hints

- In an X session, you change the layout in the X configuration file or, 
at runtime by executing, e.g.,  `setxkbmap -layout gb`, Isn't this 
easier than hunting through a bunch of menus and dialog boxes?)

- If you really need to write to the root filesystem (other than those
parts that have read-write overlays) you can run:

    # mount -rw,remount /

Of course, any changes made this way will be lost if you write a new
image to the SD card.

- No swap partition is created, because it is expected that a Linux
this light-weight will not need it. In a pinch, however, you can create a 
swapfile on the USB flash drive. Just create an empty file of whatever
size you need, run `mkswap` on it, and then `swapon`.  
 
- To get a web browser, add <code>firefox-esr</code> to the
optional packges list in `BUILDCONFIG.sh`. Other browsers might
work, but I haven't tested any.

- Many applications (including the X server) will complain about 
lack of D-Bus support, will but
still work, albeit with reduced functionality. For example,
the Thunar file manager uses D-Bus, if it can connect to it, 
to get notifications
of storage changes. It will work without this feature but, of course,
you won't get automatic updates when something changes.

- If Linux doesn't even boot as far as a console, edit `cmdline.txt` on
the first partition of the boot disk, and remove `quiet`. This slows
the boot, but at least you stand a chance of seeing what's going on.

- If you use X, and the OpenBox window manager, you can draw a background
wallpaper image by running:

    $ feh --bg-fill /path/to/picture.jpg
    
- The latest Raspbian builds no longer contain the <code>omxplayer</code>
media player. Apparently, the work that previous went into 
this player has been transferred to VLC. VLC does work on even a
Pi 3B, but you'll get a lot of frame-dropping with high-resolution
video. This was not the case with <code>omxplayer</code>.

## The Old Time advantage

The file `screenshot.png` shows an X session, running `xcalc` and the `VLC`
media player, with the OpenBox window manager.  What's important here is how
little extra software is running during this session. Here is a complete
listing of all the non-kernel processes running at this time:

    kevin@console:~$ ps --ppid 2 -p 2 --deselect
      PID TTY          TIME CMD
	1 ?        00:00:02 init
      108 ?        00:00:00 syslogd
      154 tty1     00:00:00 getty
      155 tty2     00:00:00 login
      156 tty3     00:00:00 getty
      183 ?        00:00:00 wpa_supplicant
      209 ?        00:00:00 dhcpcd
      224 ?        00:00:00 sshd
      240 tty2     00:00:00 sh
      350 tty2     00:00:00 startx
      372 tty2     00:00:00 xinit
      373 tty2     00:00:05 Xorg
      377 tty2     00:00:00 sh
      405 ?        00:00:00 ssh-agent
      406 tty2     00:00:00 xterm
      409 tty2     00:00:01 openbox
      411 pts/0    00:00:00 sh
     1098 pts/0    00:00:00 xcalc
     1206 pts/0    00:00:04 vlc
     1475 ?        00:00:00 sshd
     1496 ?        00:00:00 sshd
     1497 pts/1    00:00:00 sh
     2721 pts/1    00:00:00 ps

What's running? `init`, of course; `sshd` (which is optional); a `login`
process for the console that is logged in, and `getty` for the consoles that
are available, but not logged in; the network daemons `wpa_supplicant` and
`dhcpcd`; the X server and the scripts that initialize the X session; and the
actual applications. And that's it. Compare this with the dozens or even
hundreds of processes that are needed to start a regular desktop Linux.

With the applications mentioned above, the told memory used on my Pi 3 is
about 50Mb, of the total 768Mb available (after 256Mb have been taken
for the `/tmp` filesystem).
 
## Limitations

- Even if you make the root filesystem read-write, installing new packages
is not entirely robust. Not all the necessary infrastructure is in place.
In any event, many packages from the standard Raspbian repository
will need systemd, D-Bus, etc., so they won't ever work.

- I'm sorry to report that there are some Linux audio utilities that
_only_ work with PulseAudio. It's difficult to blame the maintainers
of these utilities, because Pulse is so ubiquitous. Still, this is
a regrettable development. 

- Although it's possible to use multiple USB storage devices with
this Linux installation, only the "main" flash drive, containing the
overlays and home directories, can be installed when the Pi boots.
With a root filesystem that defaults to read-only, there no easy solution
to this problem -- there's no way to tell the system which USB device
to use. I guess I could have the boot scripts looks for specific
files or directories on the storage devices, but this would require
that the "main" flash drive be set up in advance.

It's possible to plug in additional storage devices after boot. Of course,
with no autoconfiguration support, you'd have to mount them into the
filesystem administratively. I would advise using the `sync` mount option,
since there's no shut-down procedure.

- I was unable to get LibreOffice to work. However, I have to admit that
I didn't try very hard.

- Although there's an awful lot of "dependency bloat" in the Raspbian
repositories, some packages still don't specify all their dependencies.
We get away with this is a regular desktop Linux, because a huge number
of packages are installed by default. Here, we have to be willing to
add dependencies explicitly in some cases.

- Even after dealing with the above, many package won't work, because
either (a) they rely on systemd or other complex infrastructure or (b)
they require the root filesystem to be writeable. The latter problem
can usually be overcome by making judicious links from the root filesystem
to directories on the USB flash. But it might not be worth the effort.


