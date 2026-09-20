sudo ip netns exec node-b-ns tee /etc/swanctl/swanctl.d/vpp-nodeb.conf >/dev/null <<'EOF'
connections {
    vpp-nodeb {
        version = 2

        local_addrs = 192.168.50.2
        remote_addrs = 192.168.50.1

        proposals = aes256-sha256-modp2048

        local {
            auth = psk
            id = 192.168.50.2
        }

        remote {
            auth = psk
            id = 192.168.50.1
        }

        children {
            vpp-child {
                local_ts = 10.20.0.0/24
                remote_ts = 10.10.0.0/24

                esp_proposals = aes256-sha256

                start_action = start
                dpd_action = restart
            }
        }
    }
}

secrets {
    ike-psk {
        secret = "secret123"
    }
}
EOF

sudo ip netns exec node-b-ns mv \
    /etc/swanctl/swanctl.d/vpp-nodeb.conf \
    /etc/swanctl/conf.d/vpp-nodeb.conf
