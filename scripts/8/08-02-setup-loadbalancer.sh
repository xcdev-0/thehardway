#!/usr/bin/env bash

sudo apt-get update && sudo apt-get install -y haproxy

CONTROL01=$(dig +short controlplane01)
CONTROL02=$(dig +short controlplane02)
LOADBALANCER=$(dig +short loadbalancer)

cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
frontend kubernetes
    bind ${LOADBALANCER}:6443
    option tcplog
    mode tcp
    default_backend kubernetes-controlplane-nodes

backend kubernetes-controlplane-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    server controlplane01 ${CONTROL01}:6443 check fall 3 rise 2
    server controlplane02 ${CONTROL02}:6443 check fall 3 rise 2
EOF

sudo systemctl restart haproxy