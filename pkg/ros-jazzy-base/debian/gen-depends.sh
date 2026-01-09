#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

CODENAME="${CODENAME:-trixie-jazzy}"
REPO_BASE="${REPO_BASE:-/srv/aptrepo}"

PACKAGES_FILE="$REPO_BASE/dists/$CODENAME/main/binary-arm64/Packages"
DEPENDS_TXT="$SCRIPT_DIR/depends.txt"

if [[ ! -r "$PACKAGES_FILE" ]]; then
  echo "ERROR: cannot read Packages file: $PACKAGES_FILE" >&2
  echo "Hint: ensure your repo is exported: reprepro -b /srv/aptrepo export" >&2
  exit 1
fi

# Extract package names, filter to ros-jazzy-*, exclude self and debug symbols.
mapfile -t pkgs < <(
  awk -F': ' '
    $1=="Package" {print $2}
  ' "$PACKAGES_FILE" \
  | grep -E '^ros-jazzy-' \
  | grep -v -E '^(ros-jazzy-base)$' \
  | grep -v -E '.*-dbgsym$' \
  | sort -u
)

if (( ${#pkgs[@]} == 0 )); then
  echo "ERROR: no ros-jazzy-* packages found in $PACKAGES_FILE" >&2
  exit 1
fi

# Write one package per line for external tooling.
printf '%s\n' "${pkgs[@]}" > "$DEPENDS_TXT"

# Emit substvars file content for dh_gencontrol (-T)
# Format: name=value
# We include a minimal guard: apt accepts comma-separated depends.
depends_line="$(IFS=', '; echo "${pkgs[*]}")"
echo "ros-jazzy-all:Depends=$depends_line"
