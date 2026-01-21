#!/usr/bin/env bash
set -euo pipefail

# Snapshot current source repository state using vcs export
# Creates a locked .repos file with exact commit hashes for reproducibility.
# Useful for pinning working builds or before major updates.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.env.sh"; load_env

RELEASES_DIR="${RELEASES_DIR:-$BASE_DIR/releases}"
SRC_DIR="${SRC_DIR:-$WS/src}"

die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

need vcs
need date
need mkdir

[[ -d "$SRC_DIR" ]] || die "Source directory not found: $SRC_DIR"

mkdir -p "$RELEASES_DIR"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
output_file="$RELEASES_DIR/ros2.repos.${timestamp}.locked.yaml"

echo "==> Exporting exact repository state from: $SRC_DIR"
echo "==> Output file: $output_file"

cd "$WS"
vcs export --exact src > "$output_file"

echo "==> Done. Snapshot saved to:"
echo "    $output_file"
echo
echo "To restore this exact state later:"
echo "    vcs import src < $output_file"
