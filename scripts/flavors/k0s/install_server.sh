#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP required}"

# Install k0s binary
K0S_VERSION="${K0S_VERSION:-v1.29.7+k0s.0}"
curl -sSfL "https://github.com/k0sproject/k0s/releases/download/${K0S_VERSION}/k0s-${K0S_VERSION}-amd64" -o /usr/local/bin/k0s
chmod +x /usr/local/bin/k0s

# Install as a controller (single controller model)
# --enable-worker lets the controller also schedule workloads (handy on sharin / single node)
k0s install controller --single --enable-worker --force

# Apply kubelet bind-mount fix for kubevirt compatibility
bash "$(dirname "$0")/kubelet_fix.sh" || true

systemctl daemon-reload
systemctl enable --now k0scontroller

echo "[INFO] Waiting for k0s API to become reachable..."
for i in {1..90}; do
  if k0s kubectl get --raw='/readyz' >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "[INFO] Waiting for node object to exist..."
for i in {1..60}; do
  if [ "$(k0s kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')" != "0" ]; then
    break
  fi
  sleep 2
done

echo "[INFO] Waiting for node(s) to be Ready..."
k0s kubectl wait --for=condition=Ready node --all --timeout=300s
