#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
REPO_ROOT="$(dirname "$SCRIPT_PATH")"
REPO_ROOT="$(dirname "$REPO_ROOT")"
WS="${WS:-$REPO_ROOT/ros2}"
ROS_DISTRO="${ROS_DISTRO:-jazzy}"
OS_NAME="${OS_NAME:-debian}"
OS_VERSION="${OS_VERSION:-trixie}"
PKG_PATH="${1:-}"
PATTERN="${2:-}"

usage() {
  cat <<'EOF'
Usage: scripts/test_bloom_generate.sh <pkg_path> [pattern]

Run bloom-generate + patches.sh for a single package to validate Debian
packaging output and patches. pkg_path is relative to the workspace (ros2/).

Examples:
  scripts/test_bloom_generate.sh src/gazebosim/gz-plugin
  scripts/test_bloom_generate.sh src/gazebosim/gz-plugin 'gz-utils2_DIR'

Env overrides:
  WS, ROS_DISTRO, OS_NAME, OS_VERSION
EOF
}

if [ -z "$PKG_PATH" ]; then
  usage
  exit 1
fi

if [ ! -f "$WS/$PKG_PATH/package.xml" ]; then
  echo "ERROR: package.xml not found at $WS/$PKG_PATH" >&2
  exit 1
fi

echo "== Workspace: $WS"
echo "== Package: $PKG_PATH"
echo "== ROS distro: $ROS_DISTRO"
echo "== OS: $OS_NAME $OS_VERSION"

rm -rf "$WS/$PKG_PATH/debian" "$WS/$PKG_PATH/.obj-"* "$WS/$PKG_PATH/.debhelper" || true

(
  cd "$WS/$PKG_PATH"
  bloom-generate rosdebian --ros-distro "$ROS_DISTRO" --os-name "$OS_NAME" --os-version "$OS_VERSION"
)

"$WS/patches.sh" "$PKG_PATH"

if [ -n "$PATTERN" ]; then
  if command -v rg >/dev/null 2>&1; then
    rg -n "$PATTERN" "$WS/$PKG_PATH/debian"
  else
    grep -R -n -E "$PATTERN" "$WS/$PKG_PATH/debian"
  fi
fi
