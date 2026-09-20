#!/usr/bin/env bash

export VPP_BIN="$HOME/vpp-ipsec-assignment/vpp-src/vpp/build-root/build-vpp_debug-native/vpp/bin/vpp"
export VPPCTL_BIN="$HOME/vpp-ipsec-assignment/vpp-src/vpp/build-root/build-vpp_debug-native/vpp/bin/vppctl"
sudo "$VPPCTL_BIN" -s /run/vpp/cli.sock exec /etc/vpp/setup.cli
#sudo "$VPPCTL_BIN" -s /run/vpp/cli.sock exec /etc/vpp/setup_cbc_256.cli

