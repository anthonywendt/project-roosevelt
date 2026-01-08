#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP required}"
CP_IP="${2:?CP_IP required}"
JOIN_TOKEN="${3:?JOIN_TOKEN required}"

K0S_VERSION="${K0S_VERSION:-v1.29.7+k0s.0}"

log() { echo "[k0s:worker] $*"; }

# Install k0s binary
curl -sSfL "https://github.com/k0sproject/k0s/releases/download/${K0S_VERSION}/k0s-${K0S_VERSION}-amd64" -o /usr/local/bin/k0s
chmod +x /usr/local/bin/k0s

# Persist the token somewhere systemd-safe
# IMPORTANT: k0sworker.service will read this file on every start.
TOKEN_DIR="/etc/k0s"
TOKEN_FILE="${TOKEN_DIR}/k0s.token"
mkdir -p "${TOKEN_DIR}"
chmod 700 "${TOKEN_DIR}"

# Write token exactly, no extra newline games
printf '%s' "${JOIN_TOKEN}" > "${TOKEN_FILE}"
chmod 600 "${TOKEN_FILE}"

# If a worker unit already exists, don't re-install; just restart after updating token.
if systemctl is-enabled --quiet k0sworker 2>/dev/null; then
  log "k0sworker already installed; restarting to pick up token..."
  systemctl daemon-reload
  systemctl restart k0sworker || true
  systemctl enable --now k0sworker
else
  log "Installing k0s worker..."
  k0s install worker --token-file "${TOKEN_FILE}" --force
  systemctl daemon-reload
  systemctl enable --now k0sworker
fi

# Optional: kubelet bind-mount fix (cross-flavor hygiene)
bash "$(dirname "$0")/kubelet_fix.sh" apply >/dev/null 2>&1 || true

# Show quick status (best-effort)
sleep 2
systemctl status k0sworker --no-pager -l 2>/dev/null || true

log "Done."
