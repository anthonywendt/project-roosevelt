#!/usr/bin/env bash
set -euo pipefail

# Create a worker join token. Short expiry is fine for apply-time join.
# If you want longer for repeated joins, increase expiry.
k0s token create --role=worker --expiry=1h
