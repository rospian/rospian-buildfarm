#!/usr/bin/env bash
set -euo pipefail

# Health check: compare built package markers against actual ros-jazzy packages
# in the schroot, to spot missing or stale build markers.
# Env overrides: ROS_SUBDIR.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.env.sh"; load_env
exit
cd "$WS"

# Get list of actual built packages
rm -f $SBUILD_DIR/built_packages
for dep in $(sudo schroot -c trixie-arm64-sbuild -u root --directory / -- \
  apt update -qq >/dev/null 2>&1 && apt-cache search '^ros-jazzy-' | awk '{print $1}' | grep -v "\-dbgsym" | sort); do
  echo $dep >> $SBUILD_DIR/built_packages
  if [ ! -f "$SBUILD_DIR/built/.$dep" ]; then
    echo "$SBUILD_DIR/built/.$dep" is missing 
  fi  
done

# Packages flagged as being added by the build.sh script
ls -1 $SBUILD_DIR/built/.* | sed 's!.*/\.!!' | sort > $SBUILD_DIR/added_packages

# Eliminate differences
for pkg in $(comm -23 $SBUILD_DIR/added_packages $SBUILD_DIR/built_packages); do
  echo "$pkg does not exist but was added to sbuild/built"
done
