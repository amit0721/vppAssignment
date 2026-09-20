#!/usr/bin/env bash

export VPP_BIN="$HOME/vpp-ipsec-assignment/vpp-src/vpp/build-root/build-vpp_debug-native/vpp/bin/vpp"
export VPPCTL_BIN="$HOME/vpp-ipsec-assignment/vpp-src/vpp/build-root/build-vpp_debug-native/vpp/bin/vppctl"

./scripts/create-topology.sh
./scripts/configure-server.sh
sudo "$VPP_BIN" -c /etc/vpp/startup.conf


