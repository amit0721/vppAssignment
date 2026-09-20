#!/bin/bash


VPPCTL_BIN="/home/vboxuser/vpp-ipsec-assignment/vpp-src/vpp/build-root/build-vpp_debug-native/vpp/bin/vppctl"
SOCK="/run/vpp/cli.sock"

echo "Monitoring ipip0 state."
echo "Raw FIB output will be printed whenever ipip0 changes state."
echo "Press Ctrl+C to stop."
echo

previous=""

while true; do

    state=$(sudo "$VPPCTL_BIN" -s "$SOCK" \
        show interface ipip0 |
        awk '/^ipip0[[:space:]]/ {print $3}')

    if [[ "$state" != "$previous" ]]; then

        echo
        echo "============================================================"
        echo "$(date '+%Y-%m-%d %H:%M:%S') : ipip0 state changed"
        echo "${previous:-UNKNOWN} -> ${state:-UNKNOWN}"
        echo "============================================================"

        echo
        echo "---------------- RAW FIB: 10.20.0.0/24 --------------------"

        sudo "$VPPCTL_BIN" -s "$SOCK" \
            show ip fib 10.20.0.0/24

        echo
        echo "------------------------------------------------------------"

        previous="$state"
    fi

    sleep 1
done


