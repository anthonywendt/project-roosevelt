#!/usr/bin/env bash
set -euo pipefail

log() { echo "[common_prep] $*"; }

# --- Base OS prep ---
swapoff -a || true
sed -i '/ swap / s/^/#/' /etc/fstab || true

modprobe br_netfilter 2>/dev/null || true
modprobe overlay 2>/dev/null || true

# --- sysctl: base k8s networking ---
cat <<'EOF' > /etc/sysctl.d/99-k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
EOF

# --- sysctl: kubevirt/fsnotify/inotify stability ---
# KubeVirt (and busy k8s nodes) can exhaust inotify "instances" quickly.
# If max_user_instances is too low you'll see:
#   fsnotify watcher: too many open files
cat <<'EOF' > /etc/sysctl.d/98-kubevirt-inotify.conf
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=1048576
fs.inotify.max_queued_events=65536
EOF

# Apply sysctls once, after both files exist
sysctl --system

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl jq socat conntrack nftables iptables iproute2 ca-certificates

# --- IMPORTANT: avoid nft/legacy split-brain ---
# k3s/flannel + kube-proxy get weird when iptables backend flips between nft and legacy.
# Force legacy so kube-proxy and CNI program the same tables consistently.
if command -v update-alternatives >/dev/null 2>&1; then
  if [ -x /usr/sbin/iptables-legacy ]; then
    log "Forcing iptables -> iptables-legacy"
    update-alternatives --set iptables /usr/sbin/iptables-legacy || true
  fi

  if [ -x /usr/sbin/ip6tables-legacy ]; then
    log "Forcing ip6tables -> ip6tables-legacy"
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true
  fi

  # These may not exist on all systems; harmless if missing.
  if [ -x /usr/sbin/arptables-legacy ]; then
    log "Forcing arptables -> arptables-legacy"
    update-alternatives --set arptables /usr/sbin/arptables-legacy || true
  fi

  if [ -x /usr/sbin/ebtables-legacy ]; then
    log "Forcing ebtables -> ebtables-legacy"
    update-alternatives --set ebtables /usr/sbin/ebtables-legacy || true
  fi
fi

# --- Cross-flavor hygiene (k0s kubelet bind-mount can poison k3s) ---
K0S_KUBELET_BIND_LINE="/var/lib/k0s/kubelet /var/lib/kubelet none defaults,bind 0 0"

# 1) Unmount /var/lib/kubelet if mounted (lazy+recursive avoids "target is busy" spam)
if mountpoint -q /var/lib/kubelet 2>/dev/null; then
  log "Unmounting /var/lib/kubelet (cross-flavor hygiene)"
  umount -R -l /var/lib/kubelet 2>/dev/null || umount -l /var/lib/kubelet 2>/dev/null || true
fi

# 2) If the k0s bind line is in fstab, remove it so future mounts don't come back
if grep -Fq "$K0S_KUBELET_BIND_LINE" /etc/fstab 2>/dev/null; then
  log "Removing k0s kubelet bind-mount line from /etc/fstab"
  tmp="$(mktemp)"
  grep -Fv "$K0S_KUBELET_BIND_LINE" /etc/fstab > "$tmp" || true
  cat "$tmp" > /etc/fstab
  rm -f "$tmp"
fi

log "iptables version: $(iptables --version 2>/dev/null || true)"
log "inotify max_user_instances: $(cat /proc/sys/fs/inotify/max_user_instances 2>/dev/null || true)"
log "Done."
