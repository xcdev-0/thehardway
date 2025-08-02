#!/usr/bin/env bash

set -e

# this script should be run on all control plane nodes
# --- Configuration ---
ETCD_VERSION="v3.5.9"

if [ -z $ARCH ]; then
    echo "[ERROR] ARCH is not set"
    exit 1
fi

if [ -z $PRIMARY_IP ]; then
    echo "[ERROR] PRIMARY_IP is not set"
    exit 1
fi

if [ $PRIMARY_IP != $(ip route | grep default | awk '{ print $9 }') ]; then
    echo "[ERROR] PRIMARY_IP is not set to the internal IP of the primary NIC"
    exit 1
fi

# --- Download and install etcd ---
echo "[INFO] Downloading etcd binaries..."
wget -q --show-progress --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-${ARCH}.tar.gz"

echo "[INFO] Extracting etcd binaries..."
tar -xvf etcd-${ETCD_VERSION}-linux-${ARCH}.tar.gz
sudo mv etcd-${ETCD_VERSION}-linux-${ARCH}/etcd* /usr/local/bin/

# --- Configure directories and copy certs ---
echo "[INFO] Configuring etcd directories and certificates..."

# /etc/etcd: etcd configuration files
# /var/lib/etcd: etcd data directory
# /var/lib/kubernetes/pki: Kubernetes PKI directory
sudo mkdir -p /etc/etcd /var/lib/etcd /var/lib/kubernetes/pki

sudo cp etcd-server.key etcd-server.crt /etc/etcd/
sudo cp ca.crt /var/lib/kubernetes/pki/

sudo chown root:root /etc/etcd/* /var/lib/kubernetes/pki/*
sudo chmod 600 /etc/etcd/* /var/lib/kubernetes/pki/*

# create a symlink to the CA certificate in the etcd configuration directory
sudo ln -sf /var/lib/kubernetes/pki/ca.crt /etc/etcd/ca.crt

# --- Define etcd cluster members ---
CONTROL01=$(dig +short controlplane01)
CONTROL02=$(dig +short controlplane02)
ETCD_NAME=$(hostname -s)

# --- Create etcd systemd service file ---
echo "[INFO] Creating systemd unit file for etcd..."

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/etcd-server.crt \\
  --key-file=/etc/etcd/etcd-server.key \\
  --peer-cert-file=/etc/etcd/etcd-server.crt \\
  --peer-key-file=/etc/etcd/etcd-server.key \\
  --trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${PRIMARY_IP}:2380 \\
  --listen-peer-urls https://${PRIMARY_IP}:2380 \\
  --listen-client-urls https://${PRIMARY_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${PRIMARY_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controlplane01=https://${CONTROL01}:2380,controlplane02=https://${CONTROL02}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# --- Start etcd service ---
echo "[INFO] Starting etcd service..."
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

# --- Done ---
echo "[SUCCESS] etcd setup complete on ${ETCD_NAME}."
