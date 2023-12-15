#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The sd card's root path is accessible via $SDCARD variable.

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

PREP_PACKAGE_LIST="avahi-daemon iptables dnsmasq-base"

source /tmp/overlay/install_components/prep_install.sh
source /tmp/overlay/install_components/add_overlays.sh
source /tmp/overlay/install_components/reflash.sh

local_fixups() {
  # Add lost+found catalog and make it readable
  cd /boot
  mklost+found
  chmod +r /boot/lost+found

  # Fix netplan error. This is probably a bugfix for Armbian. 
  cat <<- EOF > /etc/netplan/armbian-default.yaml
  network:
    version: 2
    renderer: NetworkManager
EOF
}

set -e

echo "🍰 Reflash starting..."
prepare_build_reflash
install_reflash
add_overlays
local_fixups
echo "🍰 Custom script completed"
