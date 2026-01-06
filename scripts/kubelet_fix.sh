#!/usr/bin/env bash
set -euo pipefail

# KubeVirt expects /var/lib/kubelet. k0s defaults kubelet root under /var/lib/k0s/kubelet.
# Bind-mount it so components that assume /var/lib/kubelet behave.

mkdir -p /var/lib/k0s/kubelet /var/lib/kubelet

# If already mounted, do nothing
mountpoint -q /var/lib/kubelet && exit 0

mount --bind /var/lib/k0s/kubelet /var/lib/kubelet
