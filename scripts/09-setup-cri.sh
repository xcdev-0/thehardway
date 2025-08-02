#!/bin/bash

set -e

echo "[Step 1] Updating apt and installing dependencies..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

echo "[Step 2] Loading required kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "[Step 3] Setting kernel parameters..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo "[Step 4] Getting latest Kubernetes version..."
KUBE_LATEST=$(curl -L -s https://dl.k8s.io/release/stable.txt | awk 'BEGIN { FS="." } { printf "%s.%s", $1, $2 }')

echo "[Step 5] Adding Kubernetes apt repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBE_LATEST}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBE_LATEST}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "[Step 6] Installing containerd and Kubernetes tools..."
sudo apt update
sudo apt-get install -y containerd kubernetes-cni kubectl ipvsadm ipset

echo "[Step 7] Configuring containerd to use systemd cgroups..."
sudo mkdir -p /etc/containerd
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' | sudo tee /etc/containerd/config.toml

echo "[Step 8] Restarting containerd..."
sudo systemctl restart containerd

echo "[✅] Worker node setup complete. Ready to join the Kubernetes cluster."
