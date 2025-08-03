#!/usr/bin/env bash

# =============================================================================
# Kubernetes Worker Node Setup Script
# =============================================================================
# This script sets up a Kubernetes worker node by:
# 1. Installing kubelet and kube-proxy binaries
# 2. Configuring certificates and kubeconfig files
# 3. Setting up kubelet configuration for container runtime
# 4. Configuring kube-proxy for network proxy functionality
# 5. Creating systemd services for both components
# 
# Prerequisites:
# - This script must be run on the worker node (node01)
# - Environment variables: ARCH, PRIMARY_IP must be set
# =============================================================================

# --- Variables ---
# Define network configuration and host information
HOSTNAME=$(hostname)
POD_CIDR="10.244.0.0/16"        # CIDR range for Pod IP addresses
SERVICE_CIDR="10.96.0.0/16"     # CIDR range for Service IP addresses
CLUSTER_DNS=$(echo $SERVICE_CIDR | awk 'BEGIN {FS="."} ; { printf("%s.%s.%s.10", $1, $2, $3) }')

echo "[+] Setting up worker node: $HOSTNAME"
echo "[+] Architecture: $ARCH"
echo "[+] Pod CIDR: $POD_CIDR"
echo "[+] Service CIDR: $SERVICE_CIDR" # TODO: check if this is correct
echo "[+] Cluster DNS: $CLUSTER_DNS" # TODO: check if this is correct
echo "[+] Primary IP: $PRIMARY_IP"

# --- Download binaries ---
# Download the latest stable Kubernetes binaries for kubelet and kube-proxy
KUBE_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
wget -q --show-progress --https-only --timestamping \
  https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kube-proxy \
  https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kubelet

chmod +x kube-proxy kubelet
sudo mv kube-proxy kubelet /usr/local/bin/

# --- Create directories ---
# Create necessary directories for Kubernetes components
sudo mkdir -p \
  /var/lib/kubelet \        # kubelet data directory
  /var/lib/kube-proxy \     # kube-proxy data directory
  /var/lib/kubernetes/pki \ # certificates directory
  /var/run/kubernetes       # runtime directory

# --- Move certs and configs ---
# Move worker node certificates and kubeconfig files to secure locations
sudo mv ${HOSTNAME}.crt ${HOSTNAME}.key /var/lib/kubernetes/pki/
sudo mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubelet.kubeconfig
sudo mv ca.crt /var/lib/kubernetes/pki/
sudo chown root:root /var/lib/kubernetes/pki/* /var/lib/kubelet/*
sudo chmod 600 /var/lib/kubernetes/pki/* /var/lib/kubelet/*

# kube-proxy cert/key:
sudo mv kube-proxy.crt kube-proxy.key /var/lib/kubernetes/pki/

# --- kubelet config ---
# Create kubelet configuration file with authentication, authorization, and runtime settings
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /var/lib/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
clusterDomain: cluster.local
clusterDNS:
  - ${CLUSTER_DNS}
cgroupDriver: systemd
resolvConf: /run/systemd/resolve/resolv.conf
runtimeRequestTimeout: "15m"
tlsCertFile: /var/lib/kubernetes/pki/${HOSTNAME}.crt
tlsPrivateKeyFile: /var/lib/kubernetes/pki/${HOSTNAME}.key
registerNode: true
EOF

# --- kubelet systemd ---
# Create systemd service for kubelet with proper dependencies and configuration
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --kubeconfig=/var/lib/kubelet/kubelet.kubeconfig \\
  --node-ip=${PRIMARY_IP} \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# --- kube-proxy config ---
# Create kube-proxy configuration for network proxy and iptables mode
cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: /var/lib/kube-proxy/kube-proxy.kubeconfig
mode: iptables
clusterCIDR: ${POD_CIDR}
EOF

sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/

# --- kube-proxy systemd ---
# Create systemd service for kube-proxy
cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# --- Start services ---
# Reload systemd, enable services to start on boot, and start them immediately
sudo systemctl daemon-reload
sudo systemctl enable kubelet kube-proxy
sudo systemctl start kubelet kube-proxy

echo "[+] kubelet and kube-proxy started!"

# sudo systemctl restart kubelet kube-proxy