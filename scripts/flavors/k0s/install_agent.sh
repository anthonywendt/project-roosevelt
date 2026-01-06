#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${1:?NODE_IP required}"
CP_IP="${2:?CP_IP required}"
JOIN_TOKEN="${3:?JOIN_TOKEN required}"

# Install k0s binary
K0S_VERSION="${K0S_VERSION:-v1.29.7+k0s.0}"
curl -sSfL "https://github.com/k0sproject/k0s/releases/download/${K0S_VERSION}/k0s-${K0S_VERSION}-amd64" -o /usr/local/bin/k0s
chmod +x /usr/local/bin/k0s

# k0s worker install expects a token file, so we write it
TOKEN_FILE="/tmp/k0s_join.token"
echo "${JOIN_TOKEN}" > "${TOKEN_FILE}"
chmod 600 "${TOKEN_FILE}"

# Install worker
k0s install worker --token-file "${TOKEN_FILE}" --force

# Apply kubelet bind-mount fix for kubevirt compatibility
bash "$(dirname "$0")/kubelet_fix.sh" || true

rm -f "${TOKEN_FILE}" || true

systemctl daemon-reload
systemctl enable --now k0sworker

# Optional: if you want to force node IP, k0s/kubelet generally picks correct node IP,
# but you can add a config later. Keeping it simple for now.
