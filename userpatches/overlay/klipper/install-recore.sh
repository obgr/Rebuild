#!/bin/bash
# This script installs Klipper on a Debian 10 machine with Octoprint

PYTHONDIR="${HOME}/klippy-env"
SYSTEMDDIR="/etc/systemd/system"
KLIPPER_USER=$USER
KLIPPER_GROUP=$KLIPPER_USER

# Step 1: Install system packages
install_packages()
{
    # Packages for python cffi    
    PKGLIST="python3-virtualenv virtualenv python3-dev libffi-dev build-essential python3-cffi python3-libxml2"
    # kconfig requirements
    PKGLIST="${PKGLIST} libncurses-dev"
    # hub-ctrl and rp2040 flasher
    PKGLIST="${PKGLIST} libusb-dev libusb-1.0-0-dev"
    # ARM chip installation and building
    PKGLIST="${PKGLIST} stm32flash libnewlib-arm-none-eabi"
    PKGLIST="${PKGLIST} gcc-arm-none-eabi binutils-arm-none-eabi"
    # ADXL/Remove A1 requirements
    PKGLIST="${PKGLIST} python3-numpy python3-matplotlib"

    # Update system package info
    report_status "Running apt-get update..."
    sudo apt-get update

    # Install desired packages
    report_status "Installing packages..."
    sudo apt-get install --yes ${PKGLIST} --no-install-suggests 
}

# Step 2: Create python virtual environment
create_virtualenv()
{
    report_status "Updating python virtual environment..."

    # Create virtualenv if it doesn't already exist
    [ ! -d ${PYTHONDIR} ] && virtualenv -p /usr/bin/python3 ${PYTHONDIR}

    # Install/update dependencies
    ${PYTHONDIR}/bin/pip install -r ${SRCDIR}/scripts/klippy-requirements.txt
}

# Step 3: Install startup script
install_script()
{
# Create systemd service file
    KLIPPER_CONFIG=/home/debian/printer_data/config/printer.cfg
    KLIPPER_LOG=/var/log/klipper_logs/klippy.log
    KLIPPER_SOCKET=/tmp/klippy_uds
    report_status "Installing system start script..."
    sudo /bin/sh -c "cat > $SYSTEMDDIR/klipper.service" << EOF
#Systemd service file for klipper
[Unit]
Description=Starts klipper on startup
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
User=debian
RemainAfterExit=yes
PermissionsStartOnly=true
ExecStartPre=/usr/bin/gpioset 1 196=0
ExecStartPre=/usr/bin/gpioget 1 196
ExecStartPre=${SRCDIR}/scripts/flash-ar100.py /opt/firmware/ar100.bin
ExecStart=${PYTHONDIR}/bin/python ${SRCDIR}/klippy/klippy.py ${KLIPPER_CONFIG} -l ${KLIPPER_LOG} -a ${KLIPPER_SOCKET}
ExecStopPost=${SRCDIR}/scripts/flash-ar100.py --bl31 --halt /opt/firmware/bl31.bin
EOF
# Use systemctl to enable the klipper systemd service script
    sudo systemctl enable klipper.service
}

# Step 4: Install numpy after creating virtualenv
install_numpy(){
    /home/debian/klippy-env/bin/pip install -v numpy
}

# Step 5: Start host software
start_software()
{
    report_status "Launching Klipper host software..."
    sudo systemctl start klipper
}

# Helper functions
report_status()
{
    echo -e "\n\n###### $1"
}

verify_ready()
{
    if [ "$EUID" -eq 0 ]; then
        echo "This script must not run as root"
        exit 1
    fi
}

# Force script to exit if an error occurs
set -e

# Find SRCDIR from the pathname of this script
SRCDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"

# Run installation steps defined above
verify_ready
install_packages
create_virtualenv
install_script
install_numpy
start_software
