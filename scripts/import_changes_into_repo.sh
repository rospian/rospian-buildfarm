#!/usr/bin/env bash
set -euo pipefail

# ⚠️  EMERGENCY USE ONLY ⚠️
# This script manually imports .changes files into reprepro, bypassing normal
# build.sh workflows. Only use this to recover from repo corruption or when
# reimporting pre-built packages. Normal builds should use build.sh, which
# handles reprepro inclusion automatically.

# Include built .changes files into the local reprepro repo.
# Expects artifacts under $WS/sbuild/artifacts and uses $REPO_DIST for the target distro.
# Env overrides: ROS_SUBDIR, OS_DIST, ROS_DISTRO, REPO_DIST, APTREPO, SBUILD_DIR, ARTIFACTS_DIR.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.env.sh"; load_env

SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SCRIPT_PARENT_DIR="$(dirname "$SCRIPT_DIR")"
WS="${WS:-$SCRIPT_PARENT_DIR/$ROS_SUBDIR}"
SBUILD_DIR="${SBUILD_DIR:-$WS/sbuild}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$SBUILD_DIR/artifacts}"

if [ ! -d "$ARTIFACTS_DIR" ]; then
  echo "ERROR: artifacts directory not found: $ARTIFACTS_DIR" >&2
  exit 1
fi

shopt -s nullglob
changes_files=("$ARTIFACTS_DIR"/*.changes)
if [ ${#changes_files[@]} -eq 0 ]; then
  echo "ERROR: no .changes files found in $ARTIFACTS_DIR" >&2
  exit 1
fi

for changes in "${changes_files[@]}"; do
  src_name="$(awk -F': ' '$1=="Source"{print $2; exit}' "$changes")"
  if [ -z "$src_name" ]; then
    echo "ERROR: could not determine Source from $changes" >&2
    exit 1
  fi
  dist_name="$REPO_DIST"
  echo "Including $(basename "$changes") into $dist_name"
  reprepro -b "$APTREPO" remove "$dist_name" "$src_name" || true
  reprepro -b "$APTREPO" deleteunreferenced
  reprepro -b "$APTREPO" --ignore=wrongdistribution include "$dist_name" "$changes"
done
