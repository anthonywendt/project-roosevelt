#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP required}"
TIMEOUT="${2:-300}"

log() { echo "[k0s:wait] $*"; }

# Use k0s kubectl if available, else fallback to kubectl
if command -v k0s >/dev/null 2>&1; then
  K="sudo k0s kubectl"
else
  K="kubectl"
fi

deadline=$((SECONDS + TIMEOUT))

# Helper: run kubectl but don't explode on transient API/discovery errors
k_try() {
  set +e
  out=$($K "$@" 2>&1)
  rc=$?
  set -e
  echo "$out"
  return $rc
}

log "Waiting for a node with InternalIP ${NODE_IP} to appear (timeout: ${TIMEOUT}s)..."
while (( SECONDS < deadline )); do
  out="$(k_try get nodes -o wide)"
  if echo "$out" | grep -qE "(^|[[:space:]])${NODE_IP}([[:space:]]|$)"; then
    node_name="$(echo "$out" | awk -v ip="$NODE_IP" '$0 ~ ip {print $1; exit}')"
    if [ -n "${node_name:-}" ]; then
      log "Found node ${node_name} (IP ${NODE_IP}). Waiting for Ready..."
      # Now wait for Ready
      while (( SECONDS < deadline )); do
        # `kubectl wait` can fail if discovery is flaky; retry
        if $K wait --for=condition=Ready "node/${node_name}" --timeout=10s >/dev/null 2>&1; then
          log "node/${node_name} condition met"
          exit 0
        fi
        sleep 2
      done

      log "Timed out waiting for node/${node_name} to become Ready"
      $K get nodes -o wide || true
      exit 1
    fi
  fi

  sleep 2
done

log "Timed out waiting for any node with IP ${NODE_IP} to appear"
$K get nodes -o wide || true
exit 1
