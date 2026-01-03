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
