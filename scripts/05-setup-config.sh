#!/usr/bin/env bash

# Exit on error
set -e

echo "[*] Generating kubeconfig files..."

# Get load balancer IP
LOADBALANCER=$(dig +short loadbalancer)
if [[ -z "$LOADBALANCER" ]]; then
  echo "[!] Failed to resolve 'loadbalancer'. Check /etc/hosts or DNS setup."
  exit 1
fi

echo "→ Load Balancer IP: $LOADBALANCER"

# Kubeconfig for kube-proxy (worker nodes)
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
  --server=https://${LOADBALANCER}:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=/var/lib/kubernetes/pki/kube-proxy.crt \
  --client-key=/var/lib/kubernetes/pki/kube-proxy.key \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

# Kubeconfig for kube-controller-manager
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=/var/lib/kubernetes/pki/kube-controller-manager.crt \
  --client-key=/var/lib/kubernetes/pki/kube-controller-manager.key \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

# Kubeconfig for kube-scheduler
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=/var/lib/kubernetes/pki/kube-scheduler.crt \
  --client-key=/var/lib/kubernetes/pki/kube-scheduler.key \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

# Kubeconfig for admin user
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=admin.crt \
  --client-key=admin.key \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

echo "[✓] kubeconfig files generated!"

# Copy files to nodes
echo "[*] Copying kubeconfig files to nodes..."

for instance in node01 node02; do
  echo "→ Sending kube-proxy.kubeconfig to $instance"
  scp -o StrictHostKeyChecking=no kube-proxy.kubeconfig ${instance}:~/
done

for instance in controlplane01 controlplane02; do
  echo "→ Sending controlplane kubeconfigs to $instance"
  scp -o StrictHostKeyChecking=no \
    admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig \
    ${instance}:~/
done

echo "[✓] All kubeconfigs distributed successfully."
