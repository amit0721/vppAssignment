#!/usr/bin/env bash

set -euo pipefail

NS="node-b-ns"
CHARON="/usr/sbin/charon-systemd"
LOG="/var/log/charon-nodeb.log"

echo "============================================================"
echo " Node B strongSwan / swanctl startup"
echo " Namespace : ${NS}"
echo "============================================================"

#
# 1. Verify namespace exists
#
if ! ip netns list | grep -qw "${NS}"; then
    echo "ERROR: network namespace '${NS}' does not exist."
    exit 1
fi

echo "[1/8] Network namespace '${NS}' exists."

#
# 2. Stop host-namespace strongSwan services
#
echo "[2/8] Stopping host-namespace strongSwan services..."

sudo systemctl stop strongswan-starter.service 2>/dev/null || true
sudo systemctl stop strongswan.service 2>/dev/null || true

#
# Prevent the host services from coming back after reboot.
# This assignment uses strongSwan only inside node-b-ns.
#
#sudo systemctl disable strongswan-starter.service 2>/dev/null || true
#sudo systemctl disable strongswan.service 2>/dev/null || true

#
# This assignment uses strongSwan only inside node-b-ns.
# Stop and mask host-namespace services so they cannot
# accidentally be started by systemd.
#

sudo systemctl disable --now strongswan-starter.service 2>/dev/null || true
sudo systemctl disable --now strongswan.service 2>/dev/null || true

sudo systemctl mask strongswan-starter.service 2>/dev/null || true
sudo systemctl mask strongswan.service 2>/dev/null || true

#
# 3. Remove any stale charon-systemd inside node-b-ns
#
echo "[3/8] Checking for existing charon-systemd..."

OLD_PIDS="$(sudo ip netns exec "${NS}" pgrep -x charon-systemd || true)"

if [[ -n "${OLD_PIDS}" ]]; then
    echo "Existing charon-systemd PID(s): ${OLD_PIDS}"
    echo "Stopping existing daemon..."

    sudo ip netns exec "${NS}" pkill -TERM -x charon-systemd || true
    sleep 2

    REMAINING="$(sudo ip netns exec "${NS}" pgrep -x charon-systemd || true)"

    if [[ -n "${REMAINING}" ]]; then
        echo "Daemon still running. Sending SIGKILL..."
        sudo ip netns exec "${NS}" pkill -KILL -x charon-systemd || true
        sleep 1
    fi
fi

#
# 4. Start charon-systemd INSIDE node-b-ns
#
echo "[4/8] Starting charon-systemd inside '${NS}'..."

sudo ip netns exec "${NS}" sh -c "nohup ${CHARON} >>/var/log/charon-nodeb.log 2>&1 </dev/null &"

#
# Wait until the actual daemon exists
#
for i in {1..20}; do
    CHARON_PID="$(sudo ip netns exec "${NS}" pgrep -o -x charon-systemd || true)"

    if [[ -n "${CHARON_PID}" ]]; then
        break
    fi

    sleep 1
done

if [[ -z "${CHARON_PID:-}" ]]; then
    echo "ERROR: charon-systemd failed to start."
    echo
    echo "Last daemon log:"
    sudo tail -50 "${LOG}" || true
    exit 1
fi

echo "charon-systemd PID: ${CHARON_PID}"

#
# 5. Wait for IKE sockets and VICI
#
echo "[5/8] Waiting for IKE sockets and VICI..."

READY=0

for i in {1..20}; do

    IKE_READY="$(
        sudo ip netns exec "${NS}" \
        ss -lunp 2>/dev/null |
        grep -E ':(500|4500)\b' || true
    )"

    if [[ -S /run/charon.vici ]] && [[ -n "${IKE_READY}" ]]; then
        READY=1
        break
    fi

    sleep 1
done

if [[ "${READY}" -ne 1 ]]; then
    echo "ERROR: strongSwan did not become ready."
    echo
    echo "IKE sockets:"
    sudo ip netns exec "${NS}" ss -lunp || true
    echo
    echo "VICI:"
    sudo ls -l /run/charon.vici 2>/dev/null || true
    echo
    echo "Last daemon log:"
    sudo tail -50 "${LOG}" || true
    exit 1
fi

echo "IKE sockets and VICI are ready."

#
# 6. Load all swanctl configuration
#
echo "[6/8] Loading swanctl configuration..."

sudo ip netns exec "${NS}" \
    swanctl --load-all --noprompt

#
# 7. Initiate CHILD_SA if it is not already established
#
echo "[7/8] Checking IPsec SA..."

if sudo ip netns exec "${NS}" swanctl --list-sas 2>/dev/null |
   grep -q "vpp-nodeb"; then

    echo "IKE_SA vpp-nodeb already exists."
    echo "No new initiation required."

else

    echo "Initiating vpp-child..."

    sudo ip netns exec "${NS}" \
        swanctl --initiate --child vpp-child
fi

#
# 8. Final verification
#
echo "[8/8] Final verification..."

sleep 2

echo
echo "---------------- IKE/CHILD SAs ----------------"
sudo ip netns exec "${NS}" swanctl --list-sas

echo
echo "---------------- XFRM STATE -------------------"
sudo ip netns exec "${NS}" ip xfrm state

echo
echo "---------------- XFRM POLICY ------------------"
sudo ip netns exec "${NS}" ip xfrm policy

echo
echo "---------------- IKE SOCKETS ------------------"
sudo ip netns exec "${NS}" ss -lunp | grep -E ':(500|4500)\b'

echo
echo "============================================================"
echo " Node B strongSwan startup COMPLETE"
echo "============================================================"
