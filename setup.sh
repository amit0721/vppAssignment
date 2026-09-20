#!/usr/bin/env bash

export VPP_BIN="$HOME/vpp-ipsec-assignment/vpp-src/vpp/build-root/build-vpp_debug-native/vpp/bin/vpp"
export VPPCTL_BIN="$HOME/vpp-ipsec-assignment/vpp-src/vpp/build-root/build-vpp_debug-native/vpp/bin/vppctl"
./scripts/configure-node-b.sh

./scripts/configure-client.sh
#./scripts/swanctl-conf-generator.sh
./scripts/start-swanctl.sh
sudo "$VPPCTL_BIN" -s /run/vpp/cli.sock set interface state ipip0 up
sudo "$VPPCTL_BIN" -s /run/vpp/cli.sock set interface state local0 up
