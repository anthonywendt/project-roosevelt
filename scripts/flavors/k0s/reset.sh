#!/usr/bin/env bash
set -euo pipefail

# Stop services if present
systemctl stop k0scontroller 2>/dev/null || true
systemctl stop k0sworker 2>/dev/null || true

# Run uninstall if present
if command -v k0s >/dev/null 2>&1; then
  k0s stop 2>/dev/null || true
  k0s reset --force 2>/dev/null || true
fi

# Remove common state paths (safe if missing)
rm -rf /var/lib/k0s /etc/k0s /run/k0s || true

# Remove the binary if you want "clean slate"
rm -f /usr/local/bin/k0s || true

umount /var/lib/kubelet 2>/dev/null || true

# NOTE: We do NOT remove containerd/CNI generally; k0s reset handles most.
