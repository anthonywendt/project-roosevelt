#!/usr/bin/env bash
set -euo pipefail

log() { echo "[reset:k3s] $*"; }

REMOTE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBELET_FIX="${REMOTE_DIR}/kubelet_fix.sh"  # TF copies it everywhere in your setup

umount_best_effort() {
  local target="$1"
  if mountpoint -q "$target" 2>/dev/null; then
    # Prefer recursive+lazy to avoid "busy" spam
    umount -R -l "$target" 2>/dev/null || umount -l "$target" 2>/dev/null || umount "$target" 2>/dev/null || true
  fi
}

log "Stopping k3s services (if present)..."
systemctl stop k3s 2>/dev/null || true
systemctl stop k3s-agent 2>/dev/null || true

# Give processes a moment to exit and release mounts
sleep 2

# If a previous k0s run left the bind-mount/fstab line around, remove it.
if [ -x "$KUBELET_FIX" ]; then
  log "Removing any leftover kubelet bind-mount from other flavors..."
  bash "$KUBELET_FIX" remove >/dev/null 2>&1 || true
fi

log "Running uninstall scripts if present..."
[ -x /usr/local/bin/k3s-uninstall.sh ] && /usr/local/bin/k3s-uninstall.sh >/dev/null 2>&1 || true
[ -x /usr/local/bin/k3s-agent-uninstall.sh ] && /usr/local/bin/k3s-agent-uninstall.sh >/dev/null 2>&1 || true

log "Unmounting kubelet-related mount trees (best-effort)..."
umount_best_effort /var/lib/rancher/k3s/agent/kubelet/pods
umount_best_effort /var/lib/kubelet

log "Removing k3s state directories..."
rm -rf /etc/rancher /var/lib/rancher || true

log "Done."
