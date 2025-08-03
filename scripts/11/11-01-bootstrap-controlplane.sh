#!/usr/bin/env bash

set -e

# =============================================================================
# Kubernetes Control Plane Bootstrapping Script
# =============================================================================
# This script sets up the control plane for worker node bootstrapping by:
# 1. Creating a bootstrap token for secure worker node authentication
# 2. Setting up ClusterRoleBindings for certificate signing requests (CSRs)
# 3. Configuring automatic approval of worker node certificates
# 
# Purpose:
# - Enables worker nodes to securely join the cluster without manual intervention
# - Automates the certificate signing process for new worker nodes
# - Establishes proper RBAC permissions for node bootstrapping
# 
# Prerequisites:
# - This script must be run on the control plane node (controlplane01)
# - Kubernetes API server must be running and accessible
# - admin.kubeconfig must be present in current directory
# =============================================================================


echo "[+] Generating bootstrap token..."

# Create a bootstrap token that expires in 7 days
# This token allows worker nodes to authenticate and request certificates
EXPIRATION=$(date -u --date "+7 days" +"%Y-%m-%dT%H:%M:%SZ")

# Generate bootstrap token secret with specific permissions and expiration
cat > bootstrap-token-07401b.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-07401b
  namespace: kube-system
type: bootstrap.kubernetes.io/token
stringData:
  description: "Bootstrap token"
  token-id: 07401b
  token-secret: f395accd246ae52d
  expiration: ${EXPIRATION}
  usage-bootstrap-authentication: "true"
  usage-bootstrap-signing: "true"
  auth-extra-groups: system:bootstrappers:worker
EOF

# Apply the bootstrap token to the cluster
kubectl create -f bootstrap-token-07401b.yaml --kubeconfig admin.kubeconfig

echo "[+] Creating ClusterRoleBindings..."

# Create ClusterRoleBinding for worker node bootstrapping
# Allows worker nodes to create certificate signing requests (CSRs)
kubectl create clusterrolebinding create-csrs-for-bootstrapping \
  --clusterrole=system:node-bootstrapper \
  --group=system:bootstrappers \
  --kubeconfig admin.kubeconfig

# Create ClusterRoleBinding for automatic CSR approval
# Automatically approves certificate requests from bootstrapping worker nodes
kubectl create clusterrolebinding auto-approve-csrs-for-group \
  --clusterrole=system:certificates.k8s.io:certificatesigningrequests:nodeclient \
  --group=system:bootstrappers \
  --kubeconfig admin.kubeconfig

# Create ClusterRoleBinding for certificate renewal
# Allows existing worker nodes to renew their certificates automatically
kubectl create clusterrolebinding auto-approve-renewals-for-nodes \
  --clusterrole=system:certificates.k8s.io:certificatesigningrequests:selfnodeclient \
  --group=system:nodes \
  --kubeconfig admin.kubeconfig

echo "[✓] Control plane bootstrapping configuration complete."
