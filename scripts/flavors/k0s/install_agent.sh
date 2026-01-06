#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP required}"
CP_IP="${2:?CP_IP required}"
JOIN_TOKEN="${3:?JOIN_TOKEN required}"

K0S_VERSION="${K0S_VERSION:-v1.29.7+k0s.0}"
curl -sSfL "https://github.com/k0sproject/k0s/releases/download/${K0S_VERSION}/k0s-${K0S_VERSION}-amd64" -o /usr/local/bin/k0s
chmod +x /usr/local/bin/k0s

TOKEN_FILE="/tmp/k0s_join.token"
echo "${JOIN_TOKEN}" > "${TOKEN_FILE}"
chmod 600 "${TOKEN_FILE}"

k0s install worker --token-file "${TOKEN_FILE}" --force
rm -f "${TOKEN_FILE}" || true

systemctl daemon-reload
systemctl enable --now k0sworker

# Apply kubelet bind-mount fix after service starts (calmer startup)
bash "$(dirname "$0")/kubelet_fix.sh" apply >/dev/null 2>&1 || true
