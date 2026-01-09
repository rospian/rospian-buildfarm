#!/bin/bash
# Build and publish a single package into the local reprepro repo.
# Usage: ./build.sh <package_dir_or_name>
# Example: ./build.sh ros-jazzy-base
set -euo pipefail

SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
TARGET_PKG="${1:-}"
WS="${WS:-$SCRIPT_DIR/$TARGET_PKG}"
ROS_DISTRO="${ROS_DISTRO:-jazzy}"
OS_DIST=trixie
REPO_DIST="$OS_DIST-$ROS_DISTRO"
ARCH=arm64

# Clean previous build artifacts for the target package.
rm -f $TARGET_PKG*.buildinfo $TARGET_PKG*.changes $TARGET_PKG*.deb $TARGET_PKG*.dsc $TARGET_PKG*.tar.xz

cd $WS

# Local build for quick iteration, then clean sbuild for publishable artifacts.
dpkg-buildpackage -us -uc
# Note: schroot requires --directory / on this system when using sbuild.
DEB_BUILD_OPTIONS=nocheck sbuild --purge-deps=always --force-orig-source --no-run-lintian -d $OS_DIST --arch=$ARCH ../${TARGET_PKG}_*.dsc
# Replace any existing repo entries with the new build.
reprepro -b /srv/aptrepo remove $REPO_DIST $TARGET_PKG
reprepro -b /srv/aptrepo removesrc $REPO_DIST $TARGET_PKG
reprepro -b /srv/aptrepo include $REPO_DIST ../${TARGET_PKG}_*.changes
reprepro -b /srv/aptrepo export
sudo apt update

# If you rebuild after changing the dependency set, bump the version (recommended):
# dch -i
# e.g. 1.0-2trixie
