#!/bin/bash

set -e

# run on the worker node(node02)
# set up services for kubelet and kube-proxy

KUBE_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
POD_CIDR=10.244.0.0/16
SERVICE_CIDR=10.96.0.0/16
CLUSTER_DNS=$(echo $SERVICE_CIDR | awk -F. '{ printf("%s.%s.%s.10", $1, $2, $3) }')

echo "[+] Setting up worker node: $HOSTNAME"
echo "[+] Kube Version: $KUBE_VERSION"
echo "[+] Cluster DNS: $CLUSTER_DNS"
echo "[+] Primary IP: $PRIMARY_IP"
echo "[+] Architecture: $ARCH"

echo "[+] Downloading kubelet and kube-proxy binaries..."
wget -q --show-progress --https-only --timestamping \
  https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kube-proxy \
  https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kubelet

chmod +x kubelet kube-proxy
sudo mv kubelet kube-proxy /usr/local/bin/

echo "[+] Creating directories..."
sudo mkdir -p /var/lib/kubelet/pki /var/lib/kube-proxy /var/lib/kubernetes/pki /var/run/kubernetes

echo "[+] Moving CA and proxy certificates (assumes files already copied)..."
sudo cp ca.crt kube-proxy.crt kube-proxy.key /var/lib/kubernetes/pki/
sudo chown root:root /var/lib/kubernetes/pki/*
sudo chmod 600 /var/lib/kubernetes/pki/*

echo "[+] Creating bootstrap kubeconfig..."
LOADBALANCER=$(dig +short loadbalancer)

cat <<EOF | sudo tee /var/lib/kubelet/bootstrap-kubeconfig > /dev/null
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /var/lib/kubernetes/pki/ca.crt
    server: https://${LOADBALANCER}:6443
  name: bootstrap
contexts:
- context:
    cluster: bootstrap
    user: kubelet-bootstrap
  name: bootstrap
current-context: bootstrap
kind: Config
preferences: {}
users:
- name: kubelet-bootstrap
  user:
    token: 07401b.f395accd246ae52d
EOF

echo "[+] Creating kubelet config..."
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml > /dev/null
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
cgroupDriver: systemd
clusterDomain: "cluster.local"
clusterDNS:
  - ${CLUSTER_DNS}
registerNode: true
resolvConf: /run/systemd/resolve/resolv.conf
rotateCertificates: true
serverTLSBootstrap: true
EOF

echo "[+] Creating kubelet systemd service..."
PRIMARY_IP=$(hostname -I | awk '{print $1}')
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service > /dev/null
[Unit]
Description=Kubernetes Kubelet
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --bootstrap-kubeconfig=/var/lib/kubelet/bootstrap-kubeconfig \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --cert-dir=/var/lib/kubelet/pki/ \\
  --node-ip=${PRIMARY_IP} \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Configuring kube-proxy..."

sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/
sudo chown root:root /var/lib/kube-proxy/kube-proxy.kubeconfig
sudo chmod 600 /var/lib/kube-proxy/kube-proxy.kubeconfig

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml > /dev/null
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: /var/lib/kube-proxy/kube-proxy.kubeconfig
mode: iptables
clusterCIDR: ${POD_CIDR}
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service > /dev/null
[Unit]
Description=Kubernetes Kube Proxy

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Starting kubelet and kube-proxy..."
sudo systemctl daemon-reload
sudo systemctl enable kubelet kube-proxy
sudo systemctl start kubelet kube-proxy

echo "[✓] Worker node bootstrapping complete."
