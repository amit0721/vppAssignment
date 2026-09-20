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

# ------------------------------------------------------------
# 1. Show active IPsec SAs
# ------------------------------------------------------------

section "1. ACTIVE IPSEC SAs"

SA_OUTPUT="$(vpp show ipsec sa)"
echo "$SA_OUTPUT"

# Extract VPP SA IDs from lines such as:
# [0] sa 1 ...
# [1] sa 2 ...
#
# We use the SA ID, NOT the SPI.
SA_IDS=($(echo "$SA_OUTPUT" | awk '/^[[:space:]]*\[[0-9]+\][[:space:]]+sa[[:space:]]+[0-9]+/ {
    print $3
}'))

if [ "${#SA_IDS[@]}" -ge 2 ]; then
    SA_IN_ID="${SA_IDS[0]}"
    SA_OUT_ID="${SA_IDS[1]}"

    echo
    echo "Detected SA IDs:"
    echo "  SA_IN_ID  = $SA_IN_ID"
    echo "  SA_OUT_ID = $SA_OUT_ID"

    # --------------------------------------------------------
    # 2. Attach IPsec protection to ipip0
    # --------------------------------------------------------

    section "2. ATTACH IPSEC PROTECTION TO ipip0"

    echo "Running:"
    echo "ipsec protect ipip0 sa-in $SA_IN_ID sa-out $SA_OUT_ID"

    vpp ipsec protect ipip0 \
        sa-in "$SA_IN_ID" \
        sa-out "$SA_OUT_ID"

else
    echo
    echo "WARNING: Could not find two active IPsec SAs."
    echo "Skipping 'ipsec protect'."
    echo
    echo "This is expected if IKEv2/CHILD_SA has not been established yet."
fi

# ------------------------------------------------------------
# 3. Ensure IPIP interface is UP
# ------------------------------------------------------------

section "3. BRING ipip0 UP"

vpp set interface state ipip0 up

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
# 10. Route
# ------------------------------------------------------------

section "10. ROUTE TO 10.20.0.0/24"

vpp show ip route 10.20.0.0/24

echo
echo "============================================================"
echo "VPP IPsec diagnostic completed"
echo "============================================================"
