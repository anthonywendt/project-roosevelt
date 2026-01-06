#!/usr/bin/env bash
set -euo pipefail

log() { echo "[reset:k0s] $*"; }

REMOTE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBELET_FIX="${REMOTE_DIR}/kubelet_fix.sh"

umount_best_effort() {
  local target="$1"
  if mountpoint -q "$target" 2>/dev/null; then
    # Recursive + lazy handles the common "busy" cases cleanly
    umount -R -l "$target" 2>/dev/null || umount -l "$target" 2>/dev/null || umount "$target" 2>/dev/null || true
  fi
}

log "Stopping k0s services (if present)..."
systemctl stop k0scontroller 2>/dev/null || true
systemctl stop k0sworker 2>/dev/null || true
systemctl stop k0scontainerd 2>/dev/null || true

# Best-effort stop via k0s (if installed)
if command -v k0s >/dev/null 2>&1; then
  k0s stop >/dev/null 2>&1 || true
fi

# Give processes a moment to settle
sleep 2

# First: remove the bind-mount + fstab line (this prevents cross-flavor poisoning)
if [ -x "$KUBELET_FIX" ]; then
  log "Removing kubelet bind-mount (and fstab line) via kubelet_fix.sh..."
  bash "$KUBELET_FIX" remove >/dev/null 2>&1 || true
else
  umount_best_effort /var/lib/kubelet
fi

# Ask k0s to reset what it owns (this is the cleanest way)
if command -v k0s >/dev/null 2>&1; then
  log "Running k0s reset --force..."
  k0s reset --force >/dev/null 2>&1 || true
fi

# Now: unmount any residual k0s/containerd mount trees (best-effort)
log "Unmounting residual k0s mount trees (best-effort)..."
umount_best_effort /var/lib/k0s/kubelet/pods
umount_best_effort /run/k0s/containerd

log "Removing k0s state directories..."
rm -rf /var/lib/k0s /etc/k0s /run/k0s || true

log "Removing k0s binary (optional clean slate)..."
rm -f /usr/local/bin/k0s || true

log "Done."
