#!/usr/bin/env bash

set -u

VPPCTL_BIN="${VPPCTL_BIN:-/home/vboxuser/vpp-ipsec-assignment/vpp-src/vpp/build-root/build-vpp_debug-native/vpp/bin/vppctl}"
VPP_SOCK="/run/vpp/cli.sock"

vpp() {
    sudo "$VPPCTL_BIN" -s "$VPP_SOCK" "$@"
}

section() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

run_check() {

    echo
    echo "################################################################"
    echo "FULL VPP IPSEC DIAGNOSTIC"
    echo "TIME: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "################################################################"

    # ------------------------------------------------------------
    # 1. Show active IPsec SAs
    # ------------------------------------------------------------

    section "1. ACTIVE IPSEC SAs"

    SA_OUTPUT="$(vpp show ipsec sa)"
    echo "$SA_OUTPUT"

    # ------------------------------------------------------------
    # 2. IPsec protection
    # ------------------------------------------------------------

    section "2. IPSEC PROTECTION"

    vpp show ipsec protect

    # ------------------------------------------------------------
    # 3. Ensure IPIP interface is UP
    # ------------------------------------------------------------

    section "3. IPIP0 STATE"

    vpp show interface ipip0

    # ------------------------------------------------------------
    # 4. IKEv2 profile
    # ------------------------------------------------------------

    section "4. IKEV2 PROFILE"

    vpp show ikev2 profile

    # ------------------------------------------------------------
    # 5. Interfaces
    # ------------------------------------------------------------

    section "5. INTERFACES"

    vpp show interface

    # ------------------------------------------------------------
    # 6. Interface addresses
    # ------------------------------------------------------------

    section "6. INTERFACE ADDRESSES"

    vpp show interface addr

    # ------------------------------------------------------------
    # 7. IPIP interface
    # ------------------------------------------------------------

    section "7. IPIP0"

    vpp show interface ipip0

    # ------------------------------------------------------------
    # 8. IKEv2 SA
    # ------------------------------------------------------------

    section "8. IKEV2 SA"

    vpp show ikev2 sa

    # ------------------------------------------------------------
    # 9. IPsec tunnel protection
    # ------------------------------------------------------------

    section "9. IPSEC PROTECTION"

    vpp show ipsec protect

    # ------------------------------------------------------------
    # 10. FIB
    # ------------------------------------------------------------

    section "10. FIB TO 10.20.0.0/24"

    vpp show ip fib 10.20.0.0/24

    echo
    echo "============================================================"
    echo "VPP IPsec diagnostic completed"
    echo "============================================================"
}

# ============================================================
# Monitor ipip0 state
# ============================================================

echo
echo "============================================================"
echo "VPP IPSEC STATE MONITOR"
echo "============================================================"
echo "Monitoring ipip0 state."
echo "Full diagnostic runs whenever ipip0 changes state."
echo "Press Ctrl+C to stop."
echo "============================================================"
sudo ip netns exec client-ns ping -D -O 10.20.0.2 2>&1 &
#sudo ip netns exec node-b-ns tcpdump -ni nodeb-underlay -tttt \
#    'udp port 500 or udp port 4500 or esp' \
#    > /tmp/nodeb-underlay-tcpdump.log 2>&1 &
previous=""

while true; do

    state=$(vpp show interface ipip0 |
        awk '/^ipip0[[:space:]]/ {print $3}')

    if [[ "$state" != "$previous" ]]; then

        echo
        echo "############################################################"
        echo "$(date '+%Y-%m-%d %H:%M:%S') : ipip0 STATE CHANGE"
        echo "${previous:-UNKNOWN} -> ${state:-UNKNOWN}"
        echo "############################################################"

        run_check

        previous="$state"
    fi

    sleep 1
done
