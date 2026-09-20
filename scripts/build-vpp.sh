#!/usr/bin/env bash
set -euo pipefail

VPP_VERSION="v24.06"
SRC_ROOT="${HOME}/vpp-ipsec-assignment/vpp-src"
VPP_SRC="${SRC_ROOT}/vpp"

mkdir -p "${SRC_ROOT}"

if [[ ! -d "${VPP_SRC}/.git" ]]; then
    git clone https://github.com/FDio/vpp.git "${VPP_SRC}"
fi

cd "${VPP_SRC}"

git fetch --tags

echo "Available matching tags:"
git tag --list '*24.06*' | tail -20

git checkout "${VPP_VERSION}"

echo
echo "Selected VPP commit:"
git rev-parse HEAD

echo
echo "Building VPP..."
make build

echo
echo "Searching for binaries..."
find "${VPP_SRC}" -type f -name vpp -perm -111 | head -20
find "${VPP_SRC}" -type f -name vppctl -perm -111 | head -20

echo
echo "Searching for plugins..."
find "${VPP_SRC}" -type f -name 'ikev2_plugin.so'
find "${VPP_SRC}" -type f -name 'acl_plugin.so'
