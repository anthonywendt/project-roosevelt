#!/bin/bash
set -euo pipefail

# Configuration
PROVIDER_NAME="uds"
PROVIDER_VERSION="0.1.0-nightly"
PROVIDER_OS_ARCH="darwin_arm64"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="$PROJECT_ROOT/plugins/defenseunicorns/${PROVIDER_NAME}/${PROVIDER_VERSION}/${PROVIDER_OS_ARCH}"
EXPECTED_BINARY_NAME="terraform-provider-${PROVIDER_NAME}_v${PROVIDER_VERSION}"
PROVIDER_SOURCE_DIR="$(cd "$PROJECT_ROOT/../terraform-provider-${PROVIDER_NAME}" 2>/dev/null && pwd || echo "")"
COMMIT_SHA_FILE="$TARGET_DIR/.build_commit_sha"

# Create the target directory
mkdir -p "$TARGET_DIR"

# Check if provider source directory exists
if [ -z "$PROVIDER_SOURCE_DIR" ] || [ ! -d "$PROVIDER_SOURCE_DIR" ]; then
  echo "Error: Provider source directory not found."
  echo "Expected location: $PROJECT_ROOT/../terraform-provider-${PROVIDER_NAME}"
  echo "Please ensure terraform-provider-uds is cloned at the expected location."
  exit 1
fi

# Get the current commit SHA from the provider source
cd "$PROVIDER_SOURCE_DIR"
CURRENT_COMMIT_SHA=$(git rev-parse HEAD)
echo "Current provider commit SHA: $CURRENT_COMMIT_SHA"

# Check if we've already built this commit
if [ -f "$COMMIT_SHA_FILE" ]; then
  PREVIOUS_COMMIT_SHA=$(cat "$COMMIT_SHA_FILE")
  if [ "$CURRENT_COMMIT_SHA" = "$PREVIOUS_COMMIT_SHA" ] && [ -f "$TARGET_DIR/$EXPECTED_BINARY_NAME" ]; then
    echo "Provider already built from commit $CURRENT_COMMIT_SHA - skipping build"
    cd - > /dev/null

    # Still create/update the .tfrc file
    LOCAL_TFRC_PATH="$PROJECT_ROOT/.tfrc"
    PROVIDER_INSTALL_BLOCK=$(cat <<EOF
provider_installation {
  dev_overrides {
    "defenseunicorns/uds" = "$TARGET_DIR"
  }

  direct {
    exclude = ["defenseunicorns/uds"]
  }
}
EOF
)
    echo "Creating local .tfrc file at $LOCAL_TFRC_PATH"
    echo "$PROVIDER_INSTALL_BLOCK" > "$LOCAL_TFRC_PATH"
    echo "Local provider configuration created successfully"
    exit 0
  fi
fi

echo "Building provider ${PROVIDER_NAME} v${PROVIDER_VERSION} from source..."

# Build the provider from source
echo "Running: go build -o \"$TARGET_DIR/$EXPECTED_BINARY_NAME\" ."
go build -o "$TARGET_DIR/$EXPECTED_BINARY_NAME" .

# Return to original directory
cd - > /dev/null

# Verify the binary was created
if [ ! -f "$TARGET_DIR/$EXPECTED_BINARY_NAME" ]; then
  echo "Error: Failed to build provider binary at '$TARGET_DIR/$EXPECTED_BINARY_NAME'"
  exit 1
fi

# Make it executable
chmod +x "$TARGET_DIR/$EXPECTED_BINARY_NAME"

# Save the commit SHA for future builds
echo "$CURRENT_COMMIT_SHA" > "$COMMIT_SHA_FILE"

echo "Successfully built and installed ${PROVIDER_NAME} provider to $TARGET_DIR/$EXPECTED_BINARY_NAME"
echo "Build metadata saved (commit: $CURRENT_COMMIT_SHA)"


# Configure OpenTofu to use the built provider via local .tfrc file
LOCAL_TFRC_PATH="$PROJECT_ROOT/.tfrc"
PROVIDER_INSTALL_BLOCK=$(cat <<EOF
provider_installation {
  dev_overrides {
    "defenseunicorns/uds" = "$TARGET_DIR"
  }

  direct {
    exclude = ["defenseunicorns/uds"]
  }
}
EOF
)

echo "Creating local .tfrc file at $LOCAL_TFRC_PATH"
echo "$PROVIDER_INSTALL_BLOCK" > "$LOCAL_TFRC_PATH"
echo "Local provider configuration created successfully"
