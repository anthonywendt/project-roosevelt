#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP required}"
K0S_VERSION="${K0S_VERSION:-v1.29.7+k0s.0}"

log() { echo "[k0s:server] $*"; }

install_k0s() {
  log "Installing k0s binary ${K0S_VERSION}..."
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

ensure_controller_unit_has_worker_enabled() {
  # If a previous unit exists that was installed with --enable-worker=false (or without enable-worker=true),
  # restarting won't fix it. We must reinstall the unit.
  if [ -f /etc/systemd/system/k0scontroller.service ]; then
    if grep -q -- '--enable-worker=false' /etc/systemd/system/k0scontroller.service; then
      log "Existing k0scontroller unit has --enable-worker=false; reinstalling unit..."
      systemctl stop k0scontroller 2>/dev/null || true
      systemctl disable k0scontroller 2>/dev/null || true
      rm -f /etc/systemd/system/k0scontroller.service
      systemctl daemon-reload 2>/dev/null || true
      systemctl reset-failed 2>/dev/null || true
    fi
  fi
}

install_or_start_controller() {
  ensure_controller_unit_has_worker_enabled

  if systemctl is-enabled --quiet k0scontroller 2>/dev/null; then
    log "k0scontroller already installed; restarting."
    systemctl daemon-reload
    systemctl restart k0scontroller
    return 0
  fi

  log "Installing k0s controller WITH worker enabled..."
  k0s install controller \
    --config /etc/k0s/k0s.yaml \
    --enable-worker=true

  systemctl daemon-reload
  systemctl enable --now k0scontroller
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

wait_for_controller_node() {
  log "Waiting for peter1 to register as a Node..."
  for i in {1..120}; do
    if k0s kubectl get nodes -o wide 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "peter1"; then
      log "peter1 registered."
      return 0
    fi
    sleep 2
  done

  log "WARN: peter1 did not appear as a Node within 240s"
  k0s kubectl get nodes -o wide || true
  return 0
}

install_k0s
ensure_config
install_or_start_controller
wait_for_api

log "Sanity check: can query Kubernetes API..."
k0s kubectl get ns >/dev/null

# Optional: kubelet bind mount fix
bash "$(dirname "$0")/kubelet_fix.sh" apply >/dev/null 2>&1 || true

wait_for_controller_node
log "Done."
