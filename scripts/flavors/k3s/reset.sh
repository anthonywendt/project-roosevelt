#!/usr/bin/env bash
set -euo pipefail

systemctl stop k3s 2>/dev/null || true
systemctl stop k3s-agent 2>/dev/null || true

/usr/local/bin/k3s-uninstall.sh >/dev/null 2>&1 || true
/usr/local/bin/k3s-agent-uninstall.sh >/dev/null 2>&1 || true

rm -rf /etc/rancher /var/lib/rancher || true
