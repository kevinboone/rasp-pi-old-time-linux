#!/bin/bash
# Make changes to device permissions whenever a user logs in at the console.
# This script is expected to be run by sudo, to gain the necessary
#   privileges
chown $SUDO_USER /dev/ttyAMA0
chown $SUDO_USER /dev/fb0
chown $SUDO_USER /dev/input/*
chown -R $SUDO_USER /dev/snd/

