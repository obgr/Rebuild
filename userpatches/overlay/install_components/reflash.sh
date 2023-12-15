#!/bin/bash

install_reflash() {
    apt install -y python3-gevent python3-flask python3-requests python3-pip pv xz-utils unzip nginx gunicorn --no-install-recommends --no-install-suggests
    pip install sqlitedict
    cd /usr/src
    wget https://github.com/intelligent-agent/Reflash/releases/download/v0.2.0-RC1/reflash.tar.gz
    tar -xf reflash.tar.gz
    cd reflash
    chmod +x ./scripts/install_reflash.sh
    ./scripts/install_reflash.sh
}

install_reflash_board() {
    apt install -y python3-gevent python3-flask python3-requests python3-pip nginx gunicorn --no-install-recommends --no-install-suggests
    pip install sqlitedict
    cd /usr/src
    wget https://github.com/intelligent-agent/Reflash/releases/download/v0.2.0-RC1/reflash-board.tar.gz
    tar -xf reflash-board.tar.gz
    cd reflash
    chmod +x ./scripts/install_reflash_board.sh
    ./scripts/install_reflash_board.sh
}
