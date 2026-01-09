#!/usr/bin/env bash
# Download vendor package sources that cannot be fetched during build
# (Debian builds run in network-disconnected environments).
# Usage: run from the workspace root (ros2_base) or anywhere; paths are resolved
# relative to this script's location.
# Environment: relies on curl and tar; writes into src/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Fetching vendor package sources..."

# mcap_vendor - MCAP C++ library v1.3.1
MCAP_VERSION="v1.3.1"
MCAP_URL="https://github.com/foxglove/mcap/archive/refs/tags/releases/cpp/${MCAP_VERSION}.tar.gz"
MCAP_DEST="$SCRIPT_DIR/src/ros2/rosbag2/mcap_vendor"
MCAP_TARBALL="/tmp/mcap-${MCAP_VERSION}.tar.gz"

if [ -d "$MCAP_DEST/mcap-releases-cpp-${MCAP_VERSION}" ]; then
  echo "✓ mcap ${MCAP_VERSION} already exists, skipping download"
else
  echo "Downloading mcap ${MCAP_VERSION}..."
  mkdir -p "$MCAP_DEST"
  curl -sL "$MCAP_URL" -o "$MCAP_TARBALL"

  echo "Extracting mcap ${MCAP_VERSION}..."
  tar -xzf "$MCAP_TARBALL" -C "$MCAP_DEST"
  rm "$MCAP_TARBALL"

  echo "✓ mcap ${MCAP_VERSION} downloaded to src/ros2/rosbag2/mcap_vendor/"
fi

echo ""
echo "All vendor sources fetched successfully!"
echo ""
echo "Next steps:"
echo "  1. Continue with the README instructions (rosdep, building, etc.)"
