#!/bin/bash
set -euo pipefail

# Check for container engine
if command -v docker &>/dev/null && docker info &>/dev/null; then
  echo "✅ Docker is available and running."
elif command -v podman &>/dev/null && podman info &>/dev/null; then
  echo "✅ Podman is available and running."
else
  echo "❌ No running container engine (Docker or Podman) found." >&2
  exit 1
fi

# Check for UDS CLI
if ! command -v uds &>/dev/null; then
  echo "❌ uds CLI is not installed or not in PATH." >&2
  exit 1
else
  echo "✅ uds CLI is installed."
fi

# Check for OpenTofu
if ! command -v opentofu &>/dev/null && ! command -v tofu &>/dev/null; then
  echo "❌ OpenTofu binary (opentofu or tofu) is not installed." >&2
  exit 1
else
  echo "✅ OpenTofu binary is installed."
fi

# Check for Atmos CLI
if ! command -v atmos &>/dev/null; then
  echo "❌ atmos CLI is not installed or not in PATH." >&2
  exit 1
else
  echo "✅ atmos CLI is installed."
fi

# Check for k3d
if ! command -v k3d &>/dev/null; then
  echo "❌ k3d is not installed or not in PATH." >&2
  exit 1
else
  echo "✅ k3d is installed."
fi

# Check for GitHub CLI
if ! command -v gh &>/dev/null; then
  echo "❌ GitHub CLI (gh) is not installed or not in PATH." >&2
  exit 1
else
  echo "✅ GitHub CLI (gh) is installed."
fi
