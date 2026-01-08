#!/usr/bin/env bash
set -euo pipefail

# Generate a WORKER join token and print to stdout
k0s token create --role=worker
