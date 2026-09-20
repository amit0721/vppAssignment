#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt full-upgrade -y

sudo apt install -y \
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    vim \
    nano \
    jq \
    net-tools \
    iproute2 \
    iputils-ping \
    tcpdump \
    ethtool \
    socat \
    bridge-utils \
    netcat-openbsd \
    iperf3 \
    gdb \
    strace \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    cmake \
    ninja-build \
    meson \
    nasm \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    python3-venv \
    python3-ply \
    libnuma-dev \
    libpcap-dev \
    libssl-dev \
    libelf-dev \
    libmnl-dev \
    libnl-3-dev \
    libnl-route-3-dev \
    libcap-dev \
    clang \
    llvm \
    flex \
    bison


sudo apt update

sudo apt install -y \
    curl \
    gnupg2 \
    lsb-release \
    net-tools \
    strongswan \
    strongswan-swanctl \
    swanctl \
    build-essential \
    cmake \
    ninja-build \
    gdb \
    iproute2 \
    tcpdump \
    iperf3

sudo modprobe tun
sudo modprobe af_packet
sudo modprobe veth
sudo modprobe bridge
sudo modprobe xfrm_user
sudo modprobe xfrm_algo

cat <<'EOF'

Dependencies installed.

Next:
  ./scripts/02-install-strongswan.sh
EOF
