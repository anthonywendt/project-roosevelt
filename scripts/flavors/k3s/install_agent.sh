#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP required}"
CP_IP="${2:?CP_IP required}"
TOKEN="${3:?JOIN_TOKEN required}"

curl -sfL https://get.k3s.io | \
  K3S_URL="https://${CP_IP}:6443" \
  K3S_TOKEN="${TOKEN}" \
  INSTALL_K3S_EXEC="agent --node-ip ${NODE_IP}" \
  sh -
