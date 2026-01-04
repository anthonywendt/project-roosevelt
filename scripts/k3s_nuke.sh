#!/usr/bin/env bash
set -euo pipefail

sudo systemctl stop k3s 2>/dev/null || true
sudo systemctl stop k3s-agent 2>/dev/null || true

sudo /usr/local/bin/k3s-uninstall.sh >/dev/null 2>&1 || true
sudo /usr/local/bin/k3s-agent-uninstall.sh >/dev/null 2>&1 || true

sudo rm -rf /etc/rancher /var/lib/rancher || true
sudo rm -rf /var/lib/kubelet || true
sudo rm -rf /etc/cni /var/lib/cni || true
sudo rm -rf /run/flannel || true

# Optional: remove leftover interfaces (generally safe)
sudo ip link delete cni0 2>/dev/null || true
sudo ip link delete flannel.1 2>/dev/null || true
