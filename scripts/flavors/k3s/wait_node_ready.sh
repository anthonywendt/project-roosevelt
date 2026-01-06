#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP required}"
TIMEOUT_SECONDS="${2:-300}"

echo "[INFO] Waiting for node with IP ${NODE_IP} to appear in cluster..."
end=$((SECONDS + TIMEOUT_SECONDS))
while (( SECONDS < end )); do
  if k3s kubectl get nodes -o wide 2>/dev/null | grep -q "${NODE_IP}"; then
    break
  fi
  sleep 2
done

NODE_NAME="$(k3s kubectl get nodes -o wide 2>/dev/null | awk -v ip="${NODE_IP}" '$0 ~ ip {print $1; exit}')"
if [[ -z "${NODE_NAME}" ]]; then
  echo "[ERROR] Node with IP ${NODE_IP} not found in cluster after ${TIMEOUT_SECONDS}s"
  k3s kubectl get nodes -o wide || true
  exit 1
fi

echo "[INFO] Waiting for node ${NODE_NAME} (IP ${NODE_IP}) to be Ready..."
k3s kubectl wait --for=condition=Ready "node/${NODE_NAME}" --timeout="${TIMEOUT_SECONDS}s"
