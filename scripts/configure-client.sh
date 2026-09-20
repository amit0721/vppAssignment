#!/usr/bin/env bash

set -euo pipefail

echo "=== Waiting for VPP-created TAP ==="

for i in $(seq 1 30); do

    if sudo ip netns exec client-ns \
        ip link show tap-client-vpp >/dev/null 2>&1; then
        break
    fi

    sleep 1
done


if ! sudo ip netns exec client-ns \
    ip link show tap-client-vpp >/dev/null 2>&1; then

    echo "ERROR: tap-client-vpp was not created by VPP"
    exit 1
fi


echo "=== Configure client IP ==="

sudo ip netns exec client-ns \
    ip link set tap-client-vpp up

sudo ip netns exec client-ns \
    ip addr replace 10.10.0.2/24 dev tap-client-vpp

sudo ip netns exec client-ns \
    ip link set dev tap-client-vpp mtu 1420

sudo ip netns exec client-ns \
    ip route replace default via 10.10.0.1


echo "=== Client configuration complete ==="

sudo ip netns exec client-ns \
    ip addr show tap-client-vpp

sudo ip netns exec client-ns \
    ip route
