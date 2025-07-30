#!/usr/bin/env bash

# Script: 03-setup-client-tools.sh
# Description: Set up SSH key, copy to all nodes, and install kubectl

set -e

# ====== STEP 1: Generate SSH Key ======
echo "[*] Generating SSH key pair ..."
if [[ ! -f ~/.ssh/id_rsa ]]; then
  ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
else
  echo "[!] SSH key already exists. Skipping key generation."
fi

# ====== STEP 2: Add key to self ======
echo "[*] Adding key to authorized_keys (self)..."
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# ====== STEP 3: Define Hosts ======
NODES=("controlplane02" "loadbalancer" "node01" "node02")

# ====== STEP 4: Copy SSH Key to All Hosts ======
echo "[*] Copying SSH public key to other nodes..."
for node in "${NODES[@]}"; do
  echo "  → $node"
  ssh-copy-id -o StrictHostKeyChecking=no "$(whoami)@$node"
done

# ====== STEP 5: Test SSH Connection ======
echo "[*] Verifying passwordless SSH access..."
for node in "controlplane01" "${NODES[@]}"; do
  echo "  → Testing SSH: $node"
  ssh "$node" "echo SSH to $node successful"
done

# ====== STEP 6: Install kubectl ======
echo "[*] Installing kubectl..."

# Check if ARCH is set
if [[ -z "$ARCH" ]]; then
  echo "[!] ARCH is not set. Defaulting to 'arm64'"
  ARCH="arm64"
fi

curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# ====== STEP 7: Verify kubectl ======
echo "[*] Verifying kubectl installation..."
kubectl version --client

echo "[✓] Client tools setup complete."
