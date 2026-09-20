#!/usr/bin/env bash

set -euo pipefail

NS="node-b-ns"

echo "======================================"
echo " Configuring Node B"
echo "======================================"

echo "[1/6] Checking namespace..."

#sudo ip netns list | grep -q "^${NS}$" || {
sudo ip netns list | grep -q "^${NS}\b" || {
    echo "ERROR: ${NS} does not exist"
    exit 1
}

echo "[2/6] Bringing interfaces up..."

sudo ip netns exec "$NS" ip link set lo up
sudo ip netns exec "$NS" ip link set nodeb-underlay up
sudo ip netns exec "$NS" ip link set nodeb-server up

echo "[3/6] Configuring underlay..."

sudo ip netns exec "$NS" \
    ip addr replace 192.168.50.2/24 dev nodeb-underlay

echo "[4/6] Configuring server-side interface..."

sudo ip netns exec "$NS" \
    ip addr replace 10.20.0.1/24 dev nodeb-server

echo "[5/6] Enabling IPv4 forwarding..."

sudo ip netns exec "$NS" \
    sysctl -w net.ipv4.ip_forward=1

echo "[6/6] Configuring return route..."

sudo ip netns exec "$NS" \
    ip route replace 10.10.0.0/24 via 192.168.50.1

echo
echo "======================================"
echo " Node B configuration complete"
echo "======================================"

echo
echo "--- Node B interfaces ---"

sudo ip netns exec "$NS" ip addr

echo
echo "--- Node B routes ---"

sudo ip netns exec "$NS" ip route
