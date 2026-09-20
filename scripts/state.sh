sudo ip netns list

sudo ip netns exec node-b-ns ip -br addr

sudo ip netns exec node-b-ns ip route

sudo ip netns exec node-b-ns ping -c 3 192.168.50.1

sudo ip netns exec node-b-ns ping -c 3 10.20.0.2

command -v swanctl || true
command -v ipsec || true
command -v charon || true
command -v charon-systemd || true

ls -l /usr/libexec/ipsec/ 2>/dev/null || true

command -v swanctl || true
command -v ipsec || true
command -v charon || true
command -v charon-systemd || true

ls -l /usr/libexec/ipsec/ 2>/dev/null || true

sudo ip netns exec node-b-ns ip xfrm state
sudo ip netns exec node-b-ns ip xfrm policy
