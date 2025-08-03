#!/usr/bin/env bash

# --- Variables ---
NODE_NAME="node01"
NODE_IP=$(dig +short $NODE_NAME)
LOADBALANCER=$(dig +short loadbalancer)

echo "[+] Generating certificates for $NODE_NAME"
echo "[+] Node IP: $NODE_IP"
echo "[+] Load Balancer: $LOADBALANCER"


# --- Generate OpenSSL config ---
cat > openssl-${NODE_NAME}.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${NODE_NAME}
IP.1 = ${NODE_IP}
EOF

# --- Generate key, csr, and cert ---
openssl genrsa -out ${NODE_NAME}.key 2048
openssl req -new -key ${NODE_NAME}.key -subj "/CN=system:node:${NODE_NAME}/O=system:nodes" -out ${NODE_NAME}.csr -config openssl-${NODE_NAME}.cnf
openssl x509 -req -in ${NODE_NAME}.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out ${NODE_NAME}.crt -extensions v3_req -extfile openssl-${NODE_NAME}.cnf -days 1000

# --- Create kubeconfig ---
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
  --server=https://${LOADBALANCER}:6443 \
  --kubeconfig=${NODE_NAME}.kubeconfig

kubectl config set-credentials system:node:${NODE_NAME} \
  --client-certificate=/var/lib/kubernetes/pki/${NODE_NAME}.crt \
  --client-key=/var/lib/kubernetes/pki/${NODE_NAME}.key \
  --kubeconfig=${NODE_NAME}.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:node:${NODE_NAME} \
  --kubeconfig=${NODE_NAME}.kubeconfig

kubectl config use-context default --kubeconfig=${NODE_NAME}.kubeconfig

# --- Copy to node01 ---
scp ca.crt ${NODE_NAME}.crt ${NODE_NAME}.key ${NODE_NAME}.kubeconfig ${NODE_NAME}:~/

echo "[+] Done: Certificates and kubeconfig copied to $NODE_NAME"
