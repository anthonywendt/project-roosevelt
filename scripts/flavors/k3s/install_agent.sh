#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP required}"
CP_IP="${2:?CP_IP required}"
TOKEN="${3:?JOIN_TOKEN required}"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBELET_FIX="${DIR}/kubelet_fix.sh"

log() { echo "[k3s:agent] $*"; }

# Optional redundancy: ensure no leftover bind-mount is present
if [ -x "$KUBELET_FIX" ]; then
  log "Removing any leftover kubelet bind-mount (cross-flavor hygiene)..."
  bash "$KUBELET_FIX" remove 2>/dev/null || true
fi

if systemctl is-active --quiet k3s-agent 2>/dev/null; then
  log "k3s-agent service already active; skipping install."
else
  log "Installing k3s agent..."
  curl -sfL https://get.k3s.io | \
    K3S_URL="https://${CP_IP}:6443" \
    K3S_TOKEN="${TOKEN}" \
    INSTALL_K3S_EXEC="agent --node-ip ${NODE_IP}" \
    sh -
fi

log "Done."
