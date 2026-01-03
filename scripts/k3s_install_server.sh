#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP arg required}"
KCFG_OUT="${2:?KCFG_OUT arg required}"
OWNER_USER="${3:-ubuntu}"

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="server --node-ip ${NODE_IP} --advertise-address ${NODE_IP}" \
  sh -

mkdir -p "$(dirname "$KCFG_OUT")"
cat /etc/rancher/k3s/k3s.yaml | sed "s/127.0.0.1/${NODE_IP}/" > "$KCFG_OUT"
chown "${OWNER_USER}:${OWNER_USER}" "$KCFG_OUT"
chmod 600 "$KCFG_OUT"
