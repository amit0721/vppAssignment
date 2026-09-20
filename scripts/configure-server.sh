#!/usr/bin/env bash

set -euo pipefail

NS="server-ns"
IF="server-link"

echo "======================================"
echo " Configuring server namespace"
echo "======================================"

echo "[1/4] Checking namespace..."

sudo ip netns list | grep -q "^${NS}\b" || {
    echo "ERROR: ${NS} does not exist"
    exit 1
}

echo "[2/4] Bringing interfaces up..."

sudo ip netns exec "$NS" ip link set lo up
sudo ip netns exec "$NS" ip link set "$IF" up

echo "[3/4] Configuring server IP..."

sudo ip netns exec "$NS" \
    ip addr replace 10.20.0.2/24 dev "$IF"

echo "[4/4] Configuring default route..."

sudo ip netns exec "$NS" \
    ip route replace default via 10.20.0.1 dev "$IF"

echo
echo "======================================"
echo " Server configuration complete"
echo "======================================"

echo
echo "--- Server interface ---"

sudo ip netns exec "$NS" \
    ip addr show "$IF"

echo
echo "--- Server routes ---"

sudo ip netns exec "$NS" \
    ip route
