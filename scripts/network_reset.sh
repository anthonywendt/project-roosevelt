#!/usr/bin/env bash
set -euo pipefail
log() { echo "[net-reset] $*"; }

# Stop the kube-proxy-ish bits and CNIs from both worlds (best-effort)
log "Stopping services (best-effort)..."
systemctl stop k3s 2>/dev/null || true
systemctl stop k3s-agent 2>/dev/null || true
systemctl stop k0scontroller 2>/dev/null || true
systemctl stop k0sworker 2>/dev/null || true
systemctl stop k0scontainerd 2>/dev/null || true

sleep 2

# Flush rules to prevent "iptables backend mismatch" + stale chains poisoning next install
log "Flushing iptables (legacy) chains (best-effort)..."
iptables-legacy -F 2>/dev/null || true
iptables-legacy -t nat -F 2>/dev/null || true
iptables-legacy -t mangle -F 2>/dev/null || true
iptables-legacy -X 2>/dev/null || true
iptables-legacy -t nat -X 2>/dev/null || true
iptables-legacy -t mangle -X 2>/dev/null || true

log "Flushing nft ruleset (best-effort)..."
nft flush ruleset 2>/dev/null || true

# Remove CNI state so the next flavor can lay down a clean network
log "Removing CNI state (best-effort)..."
rm -rf /var/lib/cni /etc/cni/net.d || true
rm -rf /var/lib/rancher/k3s/agent/flannel 2>/dev/null || true

log "Done."
