#!/usr/bin/env bash
set -euo pipefail

log() { echo "[reset:k0s] $*"; }

REMOTE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBELET_FIX="${REMOTE_DIR}/kubelet_fix.sh"
NET_RESET="${REMOTE_DIR}/network_reset.sh"

umount_best_effort() {
  local target="$1"
  if mountpoint -q "$target" 2>/dev/null; then
    # Recursive + lazy handles common "busy" cases
    umount -R -l "$target" 2>/dev/null || umount -l "$target" 2>/dev/null || umount "$target" 2>/dev/null || true
  fi
}

stop_unit() {
  local unit="$1"
  systemctl stop "$unit" 2>/dev/null || true
}

disable_and_remove_unit() {
  local unit="$1"
  stop_unit "$unit"
  systemctl disable "$unit" 2>/dev/null || true
  rm -f "/etc/systemd/system/${unit}" "/lib/systemd/system/${unit}" "/usr/lib/systemd/system/${unit}" 2>/dev/null || true
}

kill_leftovers() {
  log "Killing leftover k0s/containerd/kubelet processes (best-effort)..."
  # Stop kubelet if it exists (k0s uses its own kubelet binary under /var/lib/k0s/bin)
  pkill -f "/var/lib/k0s/bin/kubelet" 2>/dev/null || true

  # containerd + shims started by k0s
  pkill -f "/run/k0s/containerd.sock" 2>/dev/null || true
  pkill -f "/var/lib/k0s/bin/containerd" 2>/dev/null || true
  pkill -f "containerd-shim-runc-v2.*-address /run/k0s/containerd.sock" 2>/dev/null || true
  pkill -f "io.containerd.runtime.v2.task/k8s.io" 2>/dev/null || true

  # give the kernel a moment to release mounts
  sleep 2
}

remove_leftover_cni_links() {
  log "Removing leftover CNI interfaces (best-effort)..."
  # k0s/kube-router commonly uses kube-bridge; other CNIs can leave these
  for link in kube-bridge cni0 flannel.1 cali0 vxlan.calico; do
    if ip link show "$link" >/dev/null 2>&1; then
      ip link del "$link" >/dev/null 2>&1 || true
    fi
  done
}

log "Stopping k0s services (if present)..."
stop_unit k0sworker.service
stop_unit k0scontroller.service
stop_unit k0scontainerd.service

# Best-effort stop via k0s (if installed)
if command -v k0s >/dev/null 2>&1; then
  k0s stop >/dev/null 2>&1 || true
fi

sleep 2
kill_leftovers

# Clean CNI/iptables (best-effort)
if [ -x "$NET_RESET" ]; then
  log "Cleaning CNI/iptables state via network_reset.sh..."
  bash "$NET_RESET" >/dev/null 2>&1 || true
fi

# Remove kubelet bind-mount + fstab line (prevents cross-flavor poisoning)
if [ -x "$KUBELET_FIX" ]; then
  log "Removing kubelet bind-mount (and fstab line) via kubelet_fix.sh..."
  bash "$KUBELET_FIX" remove >/dev/null 2>&1 || true
else
  umount_best_effort /var/lib/kubelet
fi

# Ask k0s to reset what it owns (best-effort)
if command -v k0s >/dev/null 2>&1; then
  log "Running k0s reset --force (best-effort)..."
  k0s reset --force >/dev/null 2>&1 || true
fi

# Unmount k0s/containerd mount trees before deleting paths
log "Unmounting residual k0s mount trees (best-effort)..."
umount_best_effort /var/lib/k0s/kubelet/pods
umount_best_effort /run/k0s/containerd
umount_best_effort /run/k0s
umount_best_effort /var/lib/k0s

# Sometimes the bridge persists even after kube-router is gone
remove_leftover_cni_links

# Remove token file (worker service may reference it)
rm -f /etc/k0s/k0s.token 2>/dev/null || true

# Remove systemd units so install doesn't fail with "Init already exists"
log "Removing k0s systemd units (if present)..."
disable_and_remove_unit "k0scontroller.service"
disable_and_remove_unit "k0sworker.service"
disable_and_remove_unit "k0scontainerd.service"

systemctl daemon-reload 2>/dev/null || true
systemctl reset-failed 2>/dev/null || true

# Remove all k0s state dirs (THIS was missing in your current script)
log "Removing k0s state directories..."
rm -rf /var/lib/k0s /etc/k0s /run/k0s 2>/dev/null || true

log "Removing k0s binary (optional clean slate)..."
rm -f /usr/local/bin/k0s || true

log "Done."
