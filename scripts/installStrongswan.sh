#!/usr/bin/env bash
set -euo pipefail

sudo apt update

sudo apt install -y \
    strongswan \
    strongswan-swanctl \
    charon-systemd \
    libstrongswan-extra-plugins \
    libcharon-extra-plugins

sudo mkdir -p /etc/swanctl/conf.d
sudo mkdir -p /etc/swanctl/swanctl.d
sudo mkdir -p /etc/swanctl/x509
sudo mkdir -p /etc/swanctl/x509ca
sudo mkdir -p /etc/swanctl/private
sudo mkdir -p /etc/swanctl/pub

echo "===== swanctl version ====="
swanctl --version || true

echo
echo "===== strongSwan services ====="
systemctl list-unit-files | grep -Ei 'strongswan|charon' || true

echo
echo "strongSwan installation completed."