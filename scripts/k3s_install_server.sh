#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP arg required}"
KCFG_OUT="${2:?KCFG_OUT arg required}"
OWNER_USER="${3:-ubuntu}"

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="server \
    --node-ip ${NODE_IP} \
    --advertise-address ${NODE_IP} \
    --disable=traefik \
    --disable=servicelb" \
  sh -

mkdir -p "$(dirname "$KCFG_OUT")"
sed "s/127.0.0.1/${NODE_IP}/" /etc/rancher/k3s/k3s.yaml > "$KCFG_OUT"
chown "${OWNER_USER}:${OWNER_USER}" "$KCFG_OUT"
chmod 600 "$KCFG_OUT"

# ---- Wait for k3s API to actually be up ----
echo "[INFO] Waiting for k3s API to become reachable..."
for i in {1..60}; do
  if sudo k3s kubectl get --raw='/readyz' >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# ---- Wait until at least one node exists, then wait for Ready ----
echo "[INFO] Waiting for node object to exist..."
for i in {1..60}; do
  if [ "$(sudo k3s kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')" != "0" ]; then
    break
  fi
  sleep 2
done

echo "[INFO] Waiting for node(s) to be Ready..."
sudo k3s kubectl wait --for=condition=Ready node --all --timeout=300s