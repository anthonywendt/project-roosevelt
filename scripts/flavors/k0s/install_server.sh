#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP required}"

K0S_VERSION="${K0S_VERSION:-v1.29.7+k0s.0}"
curl -sSfL "https://github.com/k0sproject/k0s/releases/download/${K0S_VERSION}/k0s-${K0S_VERSION}-amd64" -o /usr/local/bin/k0s
chmod +x /usr/local/bin/k0s

k0s install controller --single --enable-worker --force

systemctl daemon-reload
systemctl enable --now k0scontroller

echo "[INFO] Waiting for k0s API to become reachable..."
for i in {1..90}; do
  if k0s kubectl get --raw='/readyz' >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# Now that kubelet is up, apply the kubelet bind-mount for kubevirt compatibility
bash "$(dirname "$0")/kubelet_fix.sh" apply >/dev/null 2>&1 || true

echo "[INFO] Waiting for node object to exist..."
for i in {1..60}; do
  if [ "$(k0s kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')" != "0" ]; then
    break
  fi
  sleep 2
done

echo "[INFO] Waiting for node(s) to be Ready..."
k0s kubectl wait --for=condition=Ready node --all --timeout=300s
