#!/usr/bin/env bash
set -euo pipefail

swapoff -a || true
sed -i '/ swap / s/^/#/' /etc/fstab || true

modprobe br_netfilter || true

cat <<'EOF' > /etc/sysctl.d/99-k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
EOF

sysctl --system

apt-get update -y
apt-get install -y curl jq socat conntrack iptables

# ---- Cross-flavor hygiene (k0s kubelet bind-mount can poison k3s) ----
K0S_KUBELET_BIND_LINE="/var/lib/k0s/kubelet /var/lib/kubelet none defaults,bind 0 0"

# 1) Unmount /var/lib/kubelet if mounted (lazy+recursive avoids "target is busy" spam)
if mountpoint -q /var/lib/kubelet 2>/dev/null; then
  umount -R -l /var/lib/kubelet 2>/dev/null || umount -l /var/lib/kubelet 2>/dev/null || true
fi

# 2) If the k0s bind line is in fstab, remove it so future mounts don't come back
if grep -Fq "$K0S_KUBELET_BIND_LINE" /etc/fstab 2>/dev/null; then
  tmp="$(mktemp)"
  grep -Fv "$K0S_KUBELET_BIND_LINE" /etc/fstab > "$tmp" || true
  cat "$tmp" > /etc/fstab
  rm -f "$tmp"
fi