#!/usr/bin/env bash

# ============================================================
# VPP <-> Linux IPsec FORENSIC DEBUG COLLECTOR
#
# Purpose:
#   Collect one complete diagnostic dataset for the natural
#   IKE/IPsec lifecycle:
#
#       ipip0 UP
#          |
#          | normal operation
#          v
#       ipip0 DOWN
#
# This script DOES NOT:
#   - modify setup.cli
#   - modify startup.conf
#   - change DPD
#   - change SA lifetime
#   - generate ping traffic
#   - manually change ipip0
#   - restart VPP
#   - restart strongSwan
#
# Existing monitor-vpp-ipsec.sh remains separate.
#
# Output:
#
#   /tmp/vpp-ipsec-forensics-YYYYMMDD-HHMMSS/
#
#   config-and-state.txt
#   live-state.log
#   xfrm-events.log
#   strongswan-journal.log
#   vpp-trace.txt
#   environment.txt
#
#   pcap/
#       nodeb-underlay.pcap
#       nodeb-server.pcap
#       client-ns.pcap
#       server-ns.pcap
#       root-any.pcap
#       afpacket.pcap
# ============================================================

set -u
set -o pipefail

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

VPPCTL_BIN="${VPPCTL_BIN:-/home/vboxuser/vpp-ipsec-assignment/vpp-src/vpp/build-root/build-vpp_debug-native/vpp/bin/vppctl}"
VPP_SOCK="${VPP_SOCK:-/run/vpp/cli.sock}"

START_TIME="$(date '+%Y%m%d-%H%M%S')"

OUT="/tmp/vpp-ipsec-forensics-${START_TIME}"
PCAP_DIR="$OUT/pcap"

mkdir -p "$PCAP_DIR"

CONFIG_STATE="$OUT/config-and-state.txt"
LIVE_STATE="$OUT/live-state.log"
XFRM_LOG="$OUT/xfrm-events.log"
SWAN_LOG="$OUT/strongswan-journal.log"
VPP_TRACE="$OUT/vpp-trace.txt"
ENVIRONMENT="$OUT/environment.txt"

# Background process PIDs started by this script.
declare -a BG_PIDS=()

# ------------------------------------------------------------
# VPP helper
# ------------------------------------------------------------

vpp()
{
    sudo "$VPPCTL_BIN" -s "$VPP_SOCK" "$@"
}

# ------------------------------------------------------------
# Section helper
# ------------------------------------------------------------

section()
{
    echo
    echo "================================================================"
    echo "$1"
    echo "================================================================"
}

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

cleanup()
{
    trap - INT TERM EXIT

    echo
    echo "================================================================"
    echo "STOPPING FORENSIC COLLECTION"
    echo "================================================================"

    # Stop processes started by this script.
    for pid in "${BG_PIDS[@]:-}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done

    # Allow tcpdump/journal output to flush.
    sleep 2

    collect_after_state

    # --------------------------------------------------------
    # Final VPP trace
    # --------------------------------------------------------

    {
        section "FINAL VPP GRAPH TRACE"
        vpp show trace
    } > "$VPP_TRACE" 2>&1 || true

    # Clear trace after collecting it.
    vpp clear trace >/dev/null 2>&1 || true

    # --------------------------------------------------------
    # Final summary
    # --------------------------------------------------------

    {
        section "FORENSIC COLLECTION SUMMARY"

        echo "Started : $START_TIME"
        echo "Stopped : $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        echo "Output:"
        echo "$OUT"
        echo
        echo "PCAP files:"
        find "$PCAP_DIR" -maxdepth 1 -type f -printf '  %f\n' 2>/dev/null | sort

    } | tee -a "$CONFIG_STATE"

    echo
    echo "================================================================"
    echo "FORENSIC COLLECTION COMPLETE"
    echo "================================================================"
    echo
    echo "Evidence directory:"
    echo
    echo "  $OUT"
    echo

    exit 0
}

trap cleanup INT TERM EXIT

# ------------------------------------------------------------
# Environment
# ------------------------------------------------------------

collect_environment()
{
    {
        section "DATE / HOST"

        date
        hostname
        uname -a

        section "VPP PROCESS"

        ps -ef | grep '[v]pp' || true

        section "STRONGSWAN / CHARON PROCESS"

        ps -ef | grep '[c]haron' || true

        section "NETWORK NAMESPACES"

        ip netns list

        section "ROOT INTERFACES"

        ip -br link

        section "ROOT ADDRESSES"

        ip -br addr

        section "ROOT ROUTES"

        ip route

        section "NODE-B INTERFACES"

        sudo ip netns exec node-b-ns ip -br link

        section "NODE-B ADDRESSES"

        sudo ip netns exec node-b-ns ip -br addr

        section "NODE-B ROUTES"

        sudo ip netns exec node-b-ns ip route

        section "CLIENT INTERFACES"

        sudo ip netns exec client-ns ip -br link

        section "CLIENT ADDRESSES"

        sudo ip netns exec client-ns ip -br addr

        section "SERVER INTERFACES"

        sudo ip netns exec server-ns ip -br link

        section "SERVER ADDRESSES"

        sudo ip netns exec server-ns ip -br addr

        section "VPP INTERFACES"

        vpp show interface

        section "VPP HARDWARE"

        vpp show hardware

    } > "$ENVIRONMENT" 2>&1
}

# ------------------------------------------------------------
# Configuration + state snapshot
#
# Everything goes into ONE file.
# ------------------------------------------------------------

collect_before_state()
{
    {
        section "FORENSIC START"

        echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"

        section "VPP INTERFACES"

        vpp show interface

        section "VPP INTERFACE ADDRESSES"

        vpp show interface addr

        section "VPP HARDWARE"

        vpp show hardware

        section "IPIP0"

        vpp show interface ipip0

        section "VPP IKEv2 PROFILE"

        vpp show ikev2 profile

        section "VPP IKEv2 SA"

        vpp show ikev2 sa

        section "VPP IPsec SA"

        vpp show ipsec sa

        section "VPP IPsec PROTECTION"

        vpp show ipsec protect

        section "VPP FIB 10.20.0.0/24"

        vpp show ip fib 10.20.0.0/24

        section "VPP FIB 10.10.0.0/24"

        vpp show ip fib 10.10.0.0/24

        section "VPP ERRORS"

        vpp show errors

        section "VPP RUNTIME"

        vpp show runtime

        section "VPP NODE COUNTERS"

        vpp show node counters

        section "NODE-B XFRM STATE"

        sudo ip netns exec node-b-ns ip -s xfrm state

        section "NODE-B XFRM POLICY"

        sudo ip netns exec node-b-ns ip -s xfrm policy

        section "STRONGSWAN SAs"

        sudo ip netns exec node-b-ns swanctl --list-sas

        section "STRONGSWAN CONNECTIONS"

        sudo ip netns exec node-b-ns swanctl --list-conns

        section "NODE-B LINK STATISTICS"

        sudo ip netns exec node-b-ns ip -s link

    } > "$CONFIG_STATE" 2>&1
}

# ------------------------------------------------------------
# AFTER snapshot
# Appends to SAME config-and-state.txt
# ------------------------------------------------------------

collect_after_state()
{
    {
        section "FORENSIC END"

        echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"

        section "VPP INTERFACES"

        vpp show interface

        section "VPP INTERFACE ADDRESSES"

        vpp show interface addr

        section "VPP HARDWARE"

        vpp show hardware

        section "IPIP0"

        vpp show interface ipip0

        section "VPP IKEv2 PROFILE"

        vpp show ikev2 profile

        section "VPP IKEv2 SA"

        vpp show ikev2 sa

        section "VPP IPsec SA"

        vpp show ipsec sa

        section "VPP IPsec PROTECTION"

        vpp show ipsec protect

        section "VPP FIB 10.20.0.0/24"

        vpp show ip fib 10.20.0.0/24

        section "VPP FIB 10.10.0.0/24"

        vpp show ip fib 10.10.0.0/24

        section "VPP ERRORS"

        vpp show errors

        section "VPP RUNTIME"

        vpp show runtime

        section "VPP NODE COUNTERS"

        vpp show node counters

        section "NODE-B XFRM STATE"

        sudo ip netns exec node-b-ns ip -s xfrm state

        section "NODE-B XFRM POLICY"

        sudo ip netns exec node-b-ns ip -s xfrm policy

        section "STRONGSWAN SAs"

        sudo ip netns exec node-b-ns swanctl --list-sas

        section "STRONGSWAN CONNECTIONS"

        sudo ip netns exec node-b-ns swanctl --list-conns

        section "NODE-B LINK STATISTICS"

        sudo ip netns exec node-b-ns ip -s link

    } >> "$CONFIG_STATE" 2>&1
}

# ------------------------------------------------------------
# AF_PACKET interface discovery
#
# We do not assume the Linux interface name.
# ------------------------------------------------------------

find_afpacket_interface()
{
    local candidate=""

    # Look through VPP configuration files for:
    #
    # host-interface name <interface>
    #
    for cfg in \
        /etc/vpp/startup.conf \
        /etc/vpp/setup.cli \
        "$HOME/vpp-ipsec-assignment/scripts/"*.sh
    do

        [[ -f "$cfg" ]] || continue

        candidate="$(
            grep -Eo \
            'host-interface[[:space:]]+name[[:space:]]+[A-Za-z0-9_.:-]+' \
            "$cfg" 2>/dev/null |
            awk '{print $3}' |
            head -n1
        )"

        if [[ -n "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

# ------------------------------------------------------------
# Start packet captures
# ------------------------------------------------------------

start_captures()
{
    section "STARTING PACKET CAPTURES"

    # --------------------------------------------------------
    # Node B underlay
    #
    # IKE:
    #   UDP 500
    #   UDP 4500
    #
    # ESP:
    #   IP protocol 50
    # --------------------------------------------------------

    sudo ip netns exec node-b-ns tcpdump \
        -ni nodeb-underlay \
        -tttt -vv \
        -w "$PCAP_DIR/nodeb-underlay.pcap" \
        'udp port 500 or udp port 4500 or esp' \
        > "$PCAP_DIR/nodeb-underlay.log" 2>&1 &

    BG_PIDS+=("$!")

    # --------------------------------------------------------
    # Node B server-facing interface
    # --------------------------------------------------------

    sudo ip netns exec node-b-ns tcpdump \
        -ni nodeb-server \
        -tttt -vv \
        -w "$PCAP_DIR/nodeb-server.pcap" \
        > "$PCAP_DIR/nodeb-server.log" 2>&1 &

    BG_PIDS+=("$!")

    # --------------------------------------------------------
    # Client namespace
    # --------------------------------------------------------

    sudo ip netns exec client-ns tcpdump \
        -ni any \
        -tttt -vv \
        -w "$PCAP_DIR/client-ns.pcap" \
        > "$PCAP_DIR/client-ns.log" 2>&1 &

    BG_PIDS+=("$!")

    # --------------------------------------------------------
    # Server namespace
    # --------------------------------------------------------

    sudo ip netns exec server-ns tcpdump \
        -ni any \
        -tttt -vv \
        -w "$PCAP_DIR/server-ns.pcap" \
        > "$PCAP_DIR/server-ns.log" 2>&1 &

    BG_PIDS+=("$!")
   sudo ip netns exec client-ns ping -D -O 10.20.0.2 > "$OUTDIR/ping.log" 2>&1 &
    # --------------------------------------------------------
    # Root namespace ANY
    # --------------------------------------------------------

    sudo tcpdump \
        -ni any \
        -tttt -vv \
        -w "$PCAP_DIR/root-any.pcap" \
        'udp port 500 or udp port 4500 or esp' \
        > "$PCAP_DIR/root-any.log" 2>&1 &

    BG_PIDS+=("$!")

    # --------------------------------------------------------
    # AF_PACKET backing Linux interface
    # --------------------------------------------------------

    AF_PACKET_IF="$(find_afpacket_interface || true)"

    {
        section "AF_PACKET DISCOVERY"

        if [[ -n "$AF_PACKET_IF" ]]; then

            echo "Detected Linux interface:"
            echo "$AF_PACKET_IF"

            echo
            echo "Interface information:"
            ip link show "$AF_PACKET_IF"

        else

            echo "AF_PACKET Linux backing interface was not"
            echo "automatically identified from configuration."

            echo
            echo "VPP host-vpp-underlay:"
            vpp show hardware

        fi

    } >> "$CONFIG_STATE" 2>&1

    if [[ -n "$AF_PACKET_IF" ]]; then

        sudo tcpdump \
            -ni "$AF_PACKET_IF" \
            -tttt -vv \
            -w "$PCAP_DIR/afpacket.pcap" \
            'udp port 500 or udp port 4500 or esp' \
            > "$PCAP_DIR/afpacket.log" 2>&1 &

        BG_PIDS+=("$!")

    fi
}

# ------------------------------------------------------------
# VPP graph tracing
# ------------------------------------------------------------

configure_vpp_trace()
{
    section "CONFIGURING VPP GRAPH TRACE"

    # Clear old trace.
    vpp clear trace >/dev/null 2>&1 || true

    # Each command is attempted independently.
    #
    # Some node names can differ between VPP versions.
    # A missing node does NOT cause the diagnostic to stop.

    vpp trace add virtio-input 200 \
        >> "$CONFIG_STATE" 2>&1 || true

    vpp trace add ip4-input 200 \
        >> "$CONFIG_STATE" 2>&1 || true

    vpp trace add ip4-lookup 200 \
        >> "$CONFIG_STATE" 2>&1 || true

    vpp trace add ip4-midchain 200 \
        >> "$CONFIG_STATE" 2>&1 || true

    vpp trace add esp4-encrypt-tun 200 \
        >> "$CONFIG_STATE" 2>&1 || true

    vpp trace add esp4-decrypt-tun 200 \
        >> "$CONFIG_STATE" 2>&1 || true

    vpp trace add ipsec4-tun-input 200 \
        >> "$CONFIG_STATE" 2>&1 || true
}

# ------------------------------------------------------------
# XFRM monitor
# ------------------------------------------------------------

start_xfrm_monitor()
{
    section "STARTING XFRM EVENT MONITOR"

    sudo ip netns exec node-b-ns \
        ip xfrm monitor all \
        > "$XFRM_LOG" 2>&1 &

    BG_PIDS+=("$!")
}

# ------------------------------------------------------------
# strongSwan monitor
# ------------------------------------------------------------

start_strongswan_monitor()
{
    section "STARTING STRONGSWAN STATE MONITOR"

    (
        while true; do

            echo
            echo "================================================================"
            echo "TIME: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "================================================================"

            sudo ip netns exec node-b-ns swanctl --list-sas

            sleep 1

        done
    ) > "$SWAN_LOG" 2>&1 &

    BG_PIDS+=("$!")
}

# ------------------------------------------------------------
# Live VPP/Linux state monitor
#
# One file only.
# ------------------------------------------------------------

start_live_state_monitor()
{
    section "STARTING LIVE STATE MONITOR"

    (
        while true; do

            echo
            echo "################################################################"
            echo "TIME: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "################################################################"

            echo
            echo "----- VPP IKEv2 SA -----"
            vpp show ikev2 sa

            echo
            echo "----- VPP IPsec SA -----"
            vpp show ipsec sa

            echo
            echo "----- VPP IPsec Protection -----"
            vpp show ipsec protect

            echo
            echo "----- VPP IPIP0 -----"
            vpp show interface ipip0

            echo
            echo "----- VPP Errors -----"
            vpp show errors

            echo
            echo "----- NODE B XFRM STATE -----"
            sudo ip netns exec node-b-ns ip -s xfrm state

            echo
            echo "----- NODE B XFRM POLICY -----"
            sudo ip netns exec node-b-ns ip -s xfrm policy

            echo
            echo "----- NODE B INTERFACE COUNTERS -----"
            sudo ip netns exec node-b-ns ip -s link

            sleep 1

        done
    ) > "$LIVE_STATE" 2>&1 &

    BG_PIDS+=("$!")
}

# ------------------------------------------------------------
# strongSwan journal
# ------------------------------------------------------------

start_journal_monitor()
{
    section "STARTING STRONGSWAN JOURNAL"

    sudo journalctl -f \
        > "$SWAN_LOG.journal.tmp" 2>&1 &

    BG_PIDS+=("$!")
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

section "VPP IPSEC FORENSIC DEBUGGER"

echo
echo "Output directory:"
echo
echo "  $OUT"
echo

collect_environment

collect_before_state

start_captures

configure_vpp_trace

start_xfrm_monitor

start_strongswan_monitor

start_live_state_monitor

start_journal_monitor

# ------------------------------------------------------------
# Start timestamp
# ------------------------------------------------------------

date '+%Y-%m-%d %H:%M:%S' \
    > "$OUT/start-time.txt"

# ------------------------------------------------------------
# Ready
# ------------------------------------------------------------

section "ALL FORENSIC COLLECTION IS ACTIVE"

echo
echo "============================================================"
echo "DO NOT:"
echo "============================================================"
echo
echo "  - start ping"
echo "  - change setup.cli"
echo "  - change startup.conf"
echo "  - change DPD"
echo "  - change SA lifetime"
echo "  - manually change ipip0"
echo "  - restart VPP"
echo "  - restart strongSwan"
echo
echo "============================================================"
echo "NOW RUN YOUR EXISTING NORMAL SETUP"
echo "============================================================"
echo
echo "In another terminal:"
echo
echo "  ./vppsetup.sh"
echo "  ./setup.sh"
echo "  ./monitor-vpp-ipsec.sh"
echo
echo "Let the natural:"
echo
echo "       ipip0 UP"
echo "          |"
echo "          |"
echo "       ipip0 DOWN"
echo
echo "happen."
echo
echo "After UP -> DOWN, return here and press Ctrl+C."
echo
echo "============================================================"

# ------------------------------------------------------------
# Wait
# ------------------------------------------------------------

while true; do
    sleep 10
done
