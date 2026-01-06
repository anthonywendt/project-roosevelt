#!/usr/bin/env bash
set -euo pipefail

KCFG_OUT="${1:?KCFG_OUT required}"
OWNER_USER="${2:-ubuntu}"
NODE_IP="${3:-}"

mkdir -p "$(dirname "$KCFG_OUT")"

if [[ -n "$NODE_IP" ]]; then
  sed "s/127.0.0.1/${NODE_IP}/" /etc/rancher/k3s/k3s.yaml > "$KCFG_OUT"
else
  cp /etc/rancher/k3s/k3s.yaml "$KCFG_OUT"
fi

chown "${OWNER_USER}:${OWNER_USER}" "$KCFG_OUT"
chmod 600 "$KCFG_OUT"
