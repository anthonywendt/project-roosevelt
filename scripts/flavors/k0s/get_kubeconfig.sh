#!/usr/bin/env bash
set -euo pipefail

KCFG_OUT="${1:?KCFG_OUT required}"
OWNER_USER="${2:-ubuntu}"
NODE_IP="${3:-}"

mkdir -p "$(dirname "$KCFG_OUT")"

# Generate admin kubeconfig
k0s kubeconfig admin > "$KCFG_OUT"

# Optional: rewrite server address if kubeconfig uses localhost (depends on k0s config)
if [[ -n "$NODE_IP" ]]; then
  # This is a best-effort replacement; it should be safe even if not present.
  sed -i "s/127.0.0.1/${NODE_IP}/g" "$KCFG_OUT" || true
  sed -i "s/localhost/${NODE_IP}/g" "$KCFG_OUT" || true
fi

chown "${OWNER_USER}:${OWNER_USER}" "$KCFG_OUT"
chmod 600 "$KCFG_OUT"
