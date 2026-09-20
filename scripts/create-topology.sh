#!/usr/bin/env bash
# linux topology only script
set -euo pipefail

echo "=== Creating namespaces ==="

sudo ip netns add client-ns 2>/dev/null || true
sudo ip netns add node-b-ns 2>/dev/null || true
sudo ip netns add server-ns 2>/dev/null || true


echo "=== Creating VPP <-> Node B underlay ==="

if ! ip link show vpp-underlay >/dev/null 2>&1; then
    sudo ip link add vpp-underlay type veth peer name nodeb-underlay
    sudo ip link set nodeb-underlay netns node-b-ns
fi

sudo ip link set vpp-underlay up

sudo ip netns exec node-b-ns \
    ip link set lo up

sudo ip netns exec node-b-ns \
    ip link set nodeb-underlay up

if ! sudo ip netns exec node-b-ns \
    ip addr show nodeb-underlay | grep -q "192.168.50.2/24"; then

    sudo ip netns exec node-b-ns \
        ip addr add 192.168.50.2/24 dev nodeb-underlay
fi


echo "=== Creating Node B <-> Server network ==="

if ! sudo ip netns exec node-b-ns \
    ip link show nodeb-server >/dev/null 2>&1; then

    sudo ip netns exec node-b-ns \
        ip link add nodeb-server type veth peer name server-link

    sudo ip netns exec node-b-ns \
        ip link set server-link netns server-ns
fi

sudo ip netns exec node-b-ns \
    ip link set nodeb-server up

sudo ip netns exec server-ns \
    ip link set lo up

sudo ip netns exec server-ns \
    ip link set server-link up


if ! sudo ip netns exec node-b-ns \
    ip addr show nodeb-server | grep -q "10.20.0.1/24"; then

    sudo ip netns exec node-b-ns \
        ip addr add 10.20.0.1/24 dev nodeb-server
fi


if ! sudo ip netns exec server-ns \
    ip addr show server-link | grep -q "10.20.0.2/24"; then

    sudo ip netns exec server-ns \
        ip addr add 10.20.0.2/24 dev server-link
fi


echo "=== Server route ==="

sudo ip netns exec server-ns \
    ip route replace default via 10.20.0.1


echo "=== Node B forwarding ==="

sudo ip netns exec node-b-ns \
    sysctl -w net.ipv4.ip_forward=1


echo "=== Node B return route ==="

sudo ip netns exec node-b-ns \
    ip route replace 10.10.0.0/24 via 192.168.50.1


echo "=== Topology created ==="
