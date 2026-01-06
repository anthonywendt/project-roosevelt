#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP required}"

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="server \
    --node-ip ${NODE_IP} \
    --advertise-address ${NODE_IP} \
    --disable=traefik \
    --disable=servicelb" \
  sh -

# ---- Wait for k3s API to actually be up ----
echo "[INFO] Waiting for k3s API to become reachable..."
for i in {1..60}; do
  if k3s kubectl get --raw='/readyz' >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# ---- Wait until at least one node exists, then wait for Ready ----
echo "[INFO] Waiting for node object to exist..."
for i in {1..60}; do
  if [ "$(k3s kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')" != "0" ]; then
    break
  fi
  sleep 2
done

echo "[INFO] Waiting for node(s) to be Ready..."
k3s kubectl wait --for=condition=Ready node --all --timeout=300s
