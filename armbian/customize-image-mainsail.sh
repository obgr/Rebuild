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

install_klipper(){
    cd /home/debian
    git clone https://github.com/Klipper3d/klipper
    cp /tmp/overlay/klipper/install-recore.sh /home/debian/klipper/scripts/
    cp /tmp/overlay/klipper/recore.py /home/debian/klipper/klippy/extras/
    cp /tmp/overlay/klipper/thermocouple.py /home/debian/klipper/klippy/extras/
    cp /tmp/overlay/klipper/generic-recore-a6.cfg /home/debian/klipper/config/
    cp /tmp/overlay/klipper/generic-recore-a7.cfg /home/debian/klipper/config/
    # Add compatibility with A5. 
    cp /tmp/overlay/klipper/recore_a5.py /home/debian/klipper/klippy/extras/
    cp /tmp/overlay/klipper/recore_adc_temperature.py /home/debian/klipper/klippy/extras/
    cp /tmp/overlay/klipper/recore_thermistor.py /home/debian/klipper/klippy/extras/
    cp /tmp/overlay/klipper/generic-recore-a5.cfg /home/debian/klipper/config/
    cp /tmp/overlay/klipper/tmc2209_a5.py /home/debian/klipper/klippy/extras/
    cp /tmp/overlay/klipper/tmc2130_a5.py /home/debian/klipper/klippy/extras/

	cp /tmp/overlay/klipper/flash-stm32 /usr/local/bin
	cp /tmp/overlay/klipper/flash-stm32.service /etc/systemd/system/
    mkdir -p /var/log/klipper_logs
    chown debian:debian /var/log/klipper_logs
    mkdir -p /opt/firmware/
    cp /tmp/overlay/klipper/bl31.bin /opt/firmware/
    chown -R debian:debian klipper
    chmod +x /home/debian/klipper/scripts/install-recore.sh
    su -c "/home/debian/klipper/scripts/install-recore.sh" debian
    wget http://feeds.iagent.no/toolchains/or1k-linux-musl-11.2.0.tar.xz -P /opt
    cd /opt
    tar -xf /opt/or1k-linux-musl-11.2.0.tar.xz
    rm /opt/or1k-linux-musl-11.2.0.tar.xz
    cp /tmp/overlay/klipper/ar100.config /home/debian/klipper/.config
    cd /home/debian/klipper/
    export PATH=$PATH:/opt/output/bin
	echo "export PATH=\$PATH:/opt/output/bin" >> /home/debian/.bashrc
    make olddefconfig
    make -j
    cp /home/debian/klipper/out/ar100.bin /opt/firmware
    cp /tmp/overlay/klipper/stm32f0.config /home/debian/klipper/.config
    make olddefconfig
    make -j
    cp /home/debian/klipper/out/klipper.bin /opt/firmware/stm32.bin
    chown -R debian:debian /home/debian/klipper
	systemctl enable flash-stm32.service
}

install_moonraker(){
    cd /home/debian
    git clone https://github.com/Arksine/moonraker
    chown -R debian:debian moonraker
    su -c "/home/debian/moonraker/scripts/install-moonraker.sh" debian
    su -c "/home/debian/moonraker/scripts/set-policykit-rules.sh" debian
    cp /tmp/overlay/moonraker/moonraker.conf /home/debian/printer_data/config
    cp /tmp/overlay/moonraker/recore.py /home/debian/moonraker/moonraker/components
}

install_mainsail(){
    cd /home/debian
    wget https://github.com/intelligent-agent/mainsail/releases/latest/download/mainsail.zip
    unzip mainsail.zip -d mainsail
    chown -R debian:debian mainsail
    cp /tmp/overlay/mainsail/mainsail.cfg /home/debian/printer_data/config
}

install_nginx(){
    cp /tmp/overlay/nginx/upstreams.conf /etc/nginx/conf.d/
    cp /tmp/overlay/nginx/common_vars.conf /etc/nginx/conf.d/
    cp /tmp/overlay/nginx/mainsail /etc/nginx/sites-available
    rm /etc/nginx/sites-enabled/default
    ln -s /etc/nginx/sites-available/mainsail /etc/nginx/sites-enabled/mainsail   
}

install_bins(){
    cp /tmp/overlay/bins/* /usr/local/bin
    chmod +x /usr/local/bin/*
}

install_klipperscreen() {
    cd /home/debian
    git clone https://github.com/jordanruthe/KlipperScreen.git
    chown -R debian:debian KlipperScreen
    su -c "/home/debian/KlipperScreen/scripts/KlipperScreen-install.sh" debian
}

install_ustreamer() {
    cd /home/debian
    apt install -y build-essential libevent-dev libjpeg-dev libbsd-dev
    git clone https://github.com/pikvm/ustreamer
    cd /home/debian/ustreamer
    make -j
    echo 'SUBSYSTEM=="video4linux", ATTR{name}!="cedrus", ATTR{index}=="0", SYMLINK+="webcam", TAG+="systemd"' > /etc/udev/rules.d/50-video.rules
    echo '%debian ALL=NOPASSWD: /bin/systemctl restart ustreamer.service' >> /etc/sudoers.d/debian
    cp /tmp/overlay/ustreamer/ustreamer.service /etc/systemd/system/
    systemctl enable ustreamer.service
}

install_autohotspot() {
    # Install autohotspot script
    cp /tmp/overlay/autohotspot/autohotspot /usr/local/bin
    chmod +x /usr/local/bin/autohotspot

    # Install autohotspot service file
    cp /tmp/overlay/autohotspot/autohotspot.service /etc/systemd/system/

    systemctl enable autohotspot.service
}

prepare_build() {
    PACKAGE_LIST="avahi-daemon nginx git unzip iptables dnsmasq-base"
    PACKAGE_LIST+=" python3-virtualenv virtualenv python3-dev libffi-dev build-essential python3-cffi python3-libxml2"
    PACKAGE_LIST+=" libncurses-dev libusb-dev stm32flash libnewlib-arm-none-eabi gcc-arm-none-eabi binutils-arm-none-eabi "
    apt update
    apt install -y $PACKAGE_LIST

    # Ensure the debian user exists
    useradd debian -d /home/debian -G tty,dialout -m -s /bin/bash -e -1
    echo "debian ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/debian

    # Set default passwords
    echo debian:temppwd | chpasswd
    echo root:temppwd | chpasswd

    # Force debian to change password
    chage -d 0 debian

    # Remove "dubious ownership" message when running git commands
    git config --global --add safe.directory '*'

    # Disable SSH root access
    sed -i 's/^PermitRootLogin.*$/#PermitRootLogin/g' /etc/ssh/sshd_config

    # Disable SSH. Can be enabled in Reflash
    systemctl disable ssh

    echo "ttyGS0" >> /etc/securetty

    cp /tmp/overlay/rebuild/rebuild-version /etc/
}

set -e
echo "🍰 Rebuild starting..."
prepare_build
install_klipper
install_moonraker
install_mainsail
install_nginx
install_klipperscreen
install_ustreamer
install_bins
install_autohotspot
echo "🍰 Rebuild finished"
