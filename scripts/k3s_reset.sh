#!/usr/bin/env bash
set -euo pipefail

/usr/local/bin/k3s-uninstall.sh >/dev/null 2>&1 || true
/usr/local/bin/k3s-agent-uninstall.sh >/dev/null 2>&1 || true

rm -rf /etc/rancher /var/lib/rancher || true
rm -rf /var/lib/kubelet || true
rm -rf /etc/cni /var/lib/cni || true
