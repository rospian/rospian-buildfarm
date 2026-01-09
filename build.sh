#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
ROS_SUBDIR="${ROS_SUBDIR:-ros2_base}"
WS="${WS:-$SCRIPT_DIR/$ROS_SUBDIR}"
ROS_DISTRO="${ROS_DISTRO:-jazzy}"
OS_DIST=trixie
REPO_DIST="$OS_DIST-$ROS_DISTRO"
ARCH=arm64
APTREPO="${APTREPO:-/srv/aptrepo}"
SBUILD_RESULTS="${SBUILD_RESULTS:-$WS}"
SBUILD_DIR="$WS/sbuild"
SBUILD_CHROOT="${SBUILD_CHROOT:-trixie-arm64-sbuild}"
SOURCE_CHROOT="source:${SBUILD_CHROOT}"
TARGET_PKG="${1:-}"
mkdir -p "$SBUILD_DIR"/{logs,artifacts,stamps,built}
timestamp="$(date -u +%Y%m%d_%H%M%S)"
SEQUENCE="$WS/sequence"
XREFERENCE="$SBUILD_DIR/xreference"
force_build=0
# Always force bloom generation on first run to ensure patches are applied
force_bloom=1

# Lockfile to prevent simultaneous builds against the same chroot
LOCKFILE="$SBUILD_DIR/.build.lock"

# Check if another build is already running
if [ -f "$LOCKFILE" ]; then
  LOCK_PID=$(cat "$LOCKFILE" 2>/dev/null || echo "")
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "Another build is already running (PID $LOCK_PID)"
    echo "Waiting for it to complete before starting this build..."
    echo "(Press Ctrl+C to cancel or will timeout after 300 seconds)"
    # Wait for the other process to finish (max 300 seconds)
    wait_time=0
    max_wait=300
    while kill -0 "$LOCK_PID" 2>/dev/null; do
      sleep 5
      wait_time=$((wait_time + 5))
      if [ $wait_time -ge $max_wait ]; then
        echo "ERROR: Timeout after ${max_wait} seconds waiting for build (PID $LOCK_PID) to complete"
        echo "The other build is still running. Please wait for it to finish or kill it manually."
        exit 1
      fi
    done
    echo "Previous build completed. Starting this build now."
    # Clean up the lockfile in case the other process didn't
    rm -f "$LOCKFILE"
  else
    echo "Warning: Removing stale lockfile (PID $LOCK_PID not running)"
    rm -f "$LOCKFILE"
  fi
fi

# Create lockfile with current PID
echo "$$" > "$LOCKFILE"

# Ensure lockfile is removed on exit
trap 'rm -f "$LOCKFILE"' EXIT INT TERM

cd "$WS"

cleanup_pytest_cache() {
  sudo schroot -c "$SOURCE_CHROOT" -u root --directory / -- \
    find /opt/ros/jazzy/lib/python3.13/site-packages -path '*/.pytest_cache' -prune -exec rm -rf {} + || true
}

if [ -n "$TARGET_PKG" ]; then
  # Limit to the requested package name
  PKG_PATHS=($TARGET_PKG)
  force_build=1
else
  # List package paths (one per ROS package, even if many live in one repo)
  colcon --log-base /dev/null list --base-paths src --paths-only 2>/dev/null | sort > $SBUILD_DIR/all_packages
  # Exclude skipped packages
  grep -Fvx -f skip_packages $SBUILD_DIR/all_packages > $SBUILD_DIR/inc_packages
  mapfile -t PKG_PATHS < $SBUILD_DIR/inc_packages
  # Remove old progress logs
  rm -f "$SBUILD_DIR/logs/progress_"*.log
fi

mv -f "$SBUILD_RESULTS"/*.dsc \
      "$SBUILD_RESULTS"/*.changes \
      "$SBUILD_RESULTS"/*.deb \
      "$SBUILD_RESULTS"/*.buildinfo \
      "$SBUILD_DIR/artifacts" 2>/dev/null || true

pass=1
retry=1

while [ $retry -eq 1 ]; do
  PROGRESS_LOG="$SBUILD_DIR/logs/progress_${timestamp}_${pass}.log"
  echo "===== PASS $pass =====" | tee -a "$PROGRESS_LOG"
  retry=0
  index=0
  build_count=0

  for pkg_path in "${PKG_PATHS[@]}"; do
    index=$((index + 1))

    pkg_name="$(python3 - "$pkg_path" <<'PY'
import os, sys, xml.etree.ElementTree as ET
p=sys.argv[1]
x=ET.parse(os.path.join(p,'package.xml'))
print(x.findtext('name').strip())
PY
)"

    stamp="$SBUILD_DIR/stamps/.built_pkg_${pkg_name}"
    if [ $force_build -eq 0 ] && [ -f "$stamp" ]; then
       continue
     fi

    pushd "$pkg_path" >/dev/null

    echo -e "\n" | tee -a "$PROGRESS_LOG"
    if [ ! -d "debian" ] || [ $force_bloom -eq 1 ]; then
      # Copy patched files from patches directory if they exist (before bloom)
      if [ -d "$WS/patches/$pkg_path" ]; then
        echo "== $pkg_name: applying file patches from patches/$pkg_path (pre-bloom)" | tee -a "$PROGRESS_LOG"
        cp -r "$WS/patches/$pkg_path"/* "$WS/$pkg_path/"
      fi

      echo "== ($index) $pkg_name: bloom-generate rosdebian in $pkg_path" | tee -a "$PROGRESS_LOG"
      rm -rf "$pkg_path/debian" "$pkg_path/.obj-*" "$pkg_path/.debhelper" || true
      if ! bloom-generate rosdebian --ros-distro "$ROS_DISTRO" --os-name debian --os-version "$OS_DIST" ; then
        popd >/dev/null
        echo "!! $pkg_name: bloom failed (will retry next pass)" | tee -a "$PROGRESS_LOG"
        retry=1
        continue
      fi

      # Apply patches for ros-jazzy packaging
      $WS/patches.sh "$pkg_path" | tee -a "$PROGRESS_LOG"
    fi

    # Identify debian package name
    src_name="$(dpkg-parsechangelog -S Source 2>/dev/null || true)"

    echo "== ($index) $pkg_name: $pkg_path -- $src_name" | tee -a "$PROGRESS_LOG"

    if ! awk -v p="$pkg_path" '$3==p {found=1; exit} END{exit !found}' "$XREFERENCE" 2>/dev/null; then
      echo "$src_name $pkg_name $pkg_path" >> $XREFERENCE
    fi

    # Skip packages already built
    if [ $force_build -eq 0 ] && [ -f "$stamp" ] && [ -f "$SBUILD_DIR/built/.$src_name" ]; then
      popd >/dev/null
      continue
    fi

    # Remove stamp and built marker
    rm -f $stamp
    rm -f "$SBUILD_DIR/built/.$src_name"

    # Identifiy ros-jazzy-* dependencies
    if [ $force_build == 0 ]; then
      deps=$(awk '
        BEGIN{inbd=0}
        /^Build-Depends:/ {
          inbd=1
          sub(/^Build-Depends:[[:space:]]*/, "")
          print
          next
        }
        inbd && /^[[:space:]]/ {
          print
          next
        }
        inbd && !/^[[:space:]]/ {
          exit
        }
      ' debian/control \
      | tr ',|' '\n' \
      | sed 's/([^)]*)//g' \
      | awk '{print $1}' \
      | grep -E '^ros-jazzy-' || true \
      | sort -u)
      for dep in $deps;do
        if [ ! -f "$SBUILD_DIR/built/.$dep" ]; then
          popd >/dev/null
          echo "!! $pkg_name: $dep is missing (will retry next pass)" | tee -a "$PROGRESS_LOG"
          retry=1
          continue 2
        fi  
      done  
    fi

    # Normalize changelog to a minimal valid stanza with unique timestamp version
    changelog="debian/changelog"
    first_line="$(head -n1 "$changelog")"
    src="$(echo "$first_line" | awk '{print $1}')"
    ver="$(echo "$first_line" | sed -n 's/^[^(]*(\([^)]*\)).*$/\1/p')"

    # Add timestamp to version to ensure uniqueness
    build_timestamp="$(date -u +%Y%m%d%H%M%S)"
    ver_with_timestamp="${ver}+${build_timestamp}"

    trailer="$(grep -m1 -E '^\s*-- ' "$changelog" || true)"
    if [ -z "$trailer" ]; then
      trailer=" -- $(dpkg-parsechangelog -S Maintainer 2>/dev/null || echo "Unknown <unknown@unknown>")  $(date -R)"
    fi

    cat > "$changelog" <<EOF
$src ($ver_with_timestamp) $REPO_DIST; urgency=medium

  * Automated release.

$trailer
EOF

    # Lintian overrides per binary package
    binary_pkgs=$(awk '/^Package: /{print $2}' debian/control)
    for p in $binary_pkgs; do
      if [ ! -f "debian/${p}.lintian-overrides" ]; then
        cat > "debian/${p}.lintian-overrides" <<EOF
$p: dir-or-file-in-opt opt/ros/
$p: dir-or-file-in-opt opt/ros/jazzy/
$p: dir-or-file-in-opt opt/ros/jazzy/share/
EOF
      fi
    done

    # Determine Debian source package name/version from debian/changelog
    src_ver_full="$(dpkg-parsechangelog -S Version 2>/dev/null || true)"
    src_ver="${src_ver_full%%-*}"   # upstream version part before Debian revision

    if [ -z "$src_name" ] || [ -z "$src_ver" ] || [ -z "$src_ver_full" ]; then
      popd >/dev/null
      echo "!! $pkg_name: couldn't parse Source/Version from debian/changelog" | tee -a "$PROGRESS_LOG"
      retry=1
      continue
    fi

    # Remove old build artifacts for this package
    orig="../${src_name}_${src_ver}.orig.tar.xz"
    rm -f ../"${src_name}_${src_ver}"*.dsc
    rm -f ../"${src_name}_${src_ver}"*.debian.tar.xz
    rm -f ../"${src_name}_${src_ver}"*.deb
    rm -f ../"${src_name}_${src_ver}"*.ddeb
    rm -f ../"${src_name}_${src_ver}"*.changes
    rm -f ../"${src_name}_${src_ver}"*.buildinfo

    echo "== $pkg_name: creating orig tarball: $orig" | tee -a "$PROGRESS_LOG"
    tar --exclude-vcs --exclude='./debian' -cJf "$orig" .

    # Build a source package WITHOUT checking build-deps (keeps host clean)
    echo "== $pkg_name: dpkg-source -b (no build-dep check)" | tee -a "$PROGRESS_LOG"
    if ! dpkg-source -b . > "$WS/dpkg-source.log" 2>&1; then
      popd >/dev/null
      cat "$WS/dpkg-source.log" >> "$PROGRESS_LOG"
      echo "!! $pkg_name: dpkg-source failed (will retry next pass)" | tee -a "$PROGRESS_LOG"
      retry=1
      continue
    fi
    popd >/dev/null

    dsc="$(dirname "$pkg_path")/${src_name}_${src_ver_full}.dsc"
    if [ ! -f "$dsc" ]; then
      echo "!! $pkg_name: expected .dsc not found: $dsc" | tee -a "$PROGRESS_LOG"
      retry=1
      continue
    fi

    # Ensure shared prefix is clean before sbuild installs build-deps
    cleanup_pytest_cache

    # Remove old build logs for this package
    rm -f "$WS/${src_name}_${src_ver}"*.build

    echo "== $pkg_name: sbuild -d $OS_DIST --arch=$ARCH $dsc" | tee -a "$PROGRESS_LOG"
    buildLog="${src_name}_${src_ver_full}_${ARCH}.build"
    if ! DEB_BUILD_OPTIONS=nocheck sbuild --purge-deps=always --force-orig-source --no-run-lintian -d "$OS_DIST" --arch="$ARCH" "$dsc"; then
      echo "!! $pkg_name: sbuild failed (likely missing deps); retrying in later pass" | tee -a "$PROGRESS_LOG"
      echo "!! $pkg_name: see log $WS/$buildLog" | tee -a "$PROGRESS_LOG"
      retry=1
      continue
    fi

    # Publish the newest .changes from sbuild results (safer than scraping .deb paths)
    changes="$(ls -1t "$SBUILD_RESULTS"/*.changes 2>/dev/null | head -n 1 || true)"
    if [ -n "$changes" ]; then
      echo "== $pkg_name: publish via .changes: $changes" | tee -a "$PROGRESS_LOG"
      reprepro -b "$APTREPO" remove "$REPO_DIST" "$src_name" || true
      reprepro -b "$APTREPO" deleteunreferenced
      reprepro -b "$APTREPO" include "$REPO_DIST" "$changes"
      reprepro -b "$APTREPO" export
      sudo apt update
      sudo sbuild-update -ucar "$SBUILD_CHROOT"
      touch "$SBUILD_DIR/built/.$src_name"
      touch "$stamp"
      rm -f "$SBUILD_DIR/logs/${src_name}_${src_ver}"*.build
      mv -f $buildLog  "$SBUILD_DIR/logs" 2>/dev/null || true
    else
      echo "!! $pkg_name: no .changes found in $SBUILD_RESULTS (nothing to publish?)" | tee -a "$PROGRESS_LOG"
      retry=1
      continue
    fi

    # Stash artifacts from the *workspace parent* (where dpkg-source writes them)
    echo "== $pkg_name: stash artifacts from $(dirname "$pkg_path")" | tee -a "$PROGRESS_LOG"
    mv -f "$SBUILD_RESULTS"/*.deb \
          "$SBUILD_RESULTS"/*.changes \
          "$SBUILD_RESULTS"/*.buildinfo \
          "$SBUILD_DIR/artifacts" 2>/dev/null || true

    build_count=$((build_count + 1))
    # Only append to sequence if not already present
    if ! grep -Fxq "$pkg_name" "$SEQUENCE" 2>/dev/null; then
      echo $pkg_name >> $SEQUENCE
    fi
    echo "== $pkg_name: DONE" | tee -a "$PROGRESS_LOG"
  done

  echo "Built $build_count packages" | tee -a "$PROGRESS_LOG"
  if [ $build_count == 0 ];then
    break
  fi

  pass=$((pass + 1))
  force_bloom=0

done

echo "===== Finished in $pass passes =====" | tee -a "$PROGRESS_LOG"
