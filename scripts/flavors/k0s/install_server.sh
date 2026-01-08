#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP required}"
K0S_VERSION="${K0S_VERSION:-v1.29.7+k0s.0}"

log() { echo "[k0s:server] $*"; }

install_k0s() {
  curl -sSfL "https://github.com/k0sproject/k0s/releases/download/${K0S_VERSION}/k0s-${K0S_VERSION}-amd64" -o /usr/local/bin/k0s
  chmod +x /usr/local/bin/k0s
}

ensure_config() {
  mkdir -p /etc/k0s
  if [ ! -f /etc/k0s/k0s.yaml ]; then
    log "Creating k0s config..."
    k0s config create > /etc/k0s/k0s.yaml
  fi
}

install_or_start_controller() {
  if systemctl is-enabled --quiet k0scontroller 2>/dev/null; then
    log "k0scontroller already installed; restarting."
    systemctl daemon-reload
    systemctl restart k0scontroller
  else
    log "Installing k0s controller..."
    k0s install controller --config /etc/k0s/k0s.yaml
    systemctl daemon-reload
    systemctl enable --now k0scontroller
  fi
}

wait_for_api() {
  log "Waiting for API to become reachable..."
  for i in {1..120}; do
    if k0s kubectl get --raw='/readyz' >/dev/null 2>&1; then
      log "API ready."
      return 0
    fi
    sleep 2
  done

  log "ERROR: k0s API not reachable after 240s"
  systemctl status k0scontroller --no-pager -l 2>/dev/null || true
  journalctl -u k0scontroller --no-pager -n 200 2>/dev/null || true
  return 1
}

install_or_start_worker_on_controller() {
  # Generate a local worker token and install worker service using it.
  # (This avoids needing to copy a join token from sharin.)
  log "Generating local worker join token for controller-as-worker..."
  local token
  token="$(k0s token create --role=worker)"

  log "Installing k0s worker service on controller host..."
  # Write token to a stable path so systemd ExecStart can always read it
  install -d -m 0755 /etc/k0s
  printf '%s\n' "$token" > /etc/k0s/k0s.token
  chmod 0600 /etc/k0s/k0s.token

  if systemctl is-enabled --quiet k0sworker 2>/dev/null; then
    log "k0sworker already installed on controller; restarting."
    systemctl daemon-reload
    systemctl restart k0sworker
  else
    # This creates /etc/systemd/system/k0sworker.service
    k0s install worker --token-file /etc/k0s/k0s.token --force
    systemctl daemon-reload
    systemctl enable --now k0sworker
  fi
}

wait_for_controller_node() {
  log "Waiting for this host (${NODE_IP}) to register as a Node..."
  for i in {1..90}; do
    if k0s kubectl get nodes -o wide 2>/dev/null | grep -qE "(^|[[:space:]])${NODE_IP}([[:space:]]|$)"; then
      log "Controller node registered."
      return 0
    fi
    sleep 2
  done

  log "WARN: Controller node did not register within expected time."
  k0s kubectl get nodes -o wide 2>/dev/null || true
  systemctl status k0sworker --no-pager -l 2>/dev/null || true
  journalctl -u k0sworker --no-pager -n 200 2>/dev/null || true
  return 0
}

install_k0s
ensure_config
install_or_start_controller
wait_for_api

log "Sanity check: can query Kubernetes API..."
k0s kubectl get ns >/dev/null

install_or_start_worker_on_controller

# Optional: kubelet bind mount fix
bash "$(dirname "$0")/kubelet_fix.sh" apply >/dev/null 2>&1 || true

wait_for_controller_node
log "Done."
