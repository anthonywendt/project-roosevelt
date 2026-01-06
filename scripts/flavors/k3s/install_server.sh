#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP required}"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBELET_FIX="${DIR}/kubelet_fix.sh"

log() { echo "[k3s:server] $*"; }

# Optional redundancy: ensure no leftover bind-mount is present
if [ -x "$KUBELET_FIX" ]; then
  log "Removing any leftover kubelet bind-mount (cross-flavor hygiene)..."
  bash "$KUBELET_FIX" remove 2>/dev/null || true
fi

if systemctl is-active --quiet k3s 2>/dev/null; then
  log "k3s service already active; skipping install."
else
  log "Installing k3s server..."
  curl -sfL https://get.k3s.io | \
    INSTALL_K3S_EXEC="server \
      --node-ip ${NODE_IP} \
      --advertise-address ${NODE_IP} \
      --disable=traefik \
      --disable=servicelb" \
    sh -
fi

log "Waiting for k3s API to become reachable..."
for i in {1..60}; do
  if k3s kubectl get --raw='/readyz' >/dev/null 2>&1; then
    log "API ready."
    break
  fi
  sleep 2
  if [ "$i" -eq 60 ]; then
    log "ERROR: k3s API not reachable after 120s"
    systemctl status k3s --no-pager 2>/dev/null || true
    journalctl -u k3s --no-pager -n 200 2>/dev/null || true
    exit 1
  fi
done

log "Waiting for node object to exist..."
for i in {1..60}; do
  if [ "$(k3s kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')" != "0" ]; then
    break
  fi
  sleep 2
  if [ "$i" -eq 60 ]; then
    log "ERROR: no node object appeared after 120s"
    k3s kubectl get nodes -o wide 2>/dev/null || true
    exit 1
  fi
done

log "Waiting for node(s) to be Ready..."
k3s kubectl wait --for=condition=Ready node --all --timeout=300s
log "Done."
