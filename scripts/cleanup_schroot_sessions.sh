#!/usr/bin/env bash
# cleanup_schroot_sessions.sh
#
# Purpose:
#   Cleans up active schroot sessions that may be left behind after interrupted
#   or failed ROS 2 package builds. During the Debian package build process,
#   sbuild creates temporary schroot sessions (isolated build environments) that
#   should normally terminate when the build completes. However, when builds are
#   interrupted or fail, these sessions can persist and cause issues.
#
# Why this is needed:
#   - Interrupted builds (Ctrl+C, system crashes) leave active schroot sessions
#   - Stale sessions can prevent new builds from starting
#   - Orphaned mount points can accumulate and consume system resources
#   - Multiple stale sessions can cause permission or lock conflicts
#
# What it does:
#   1. Lists all active schroot sessions
#   2. Filters sessions matching a prefix (default: trixie-arm64-sbuild)
#   3. Ends each matching session using 'schroot --end-session'
#   4. Optionally removes leftover directories (with --prune flag):
#      - /run/schroot/mount/<session>
#      - /var/lib/schroot/union/underlay/<session>
#
# Common use cases:
#   - After a build failure or interruption
#   - Before starting a fresh build to ensure clean environment
#   - When "session already exists" errors occur
#   - Periodic maintenance to clean up orphaned sessions
#
# Safety:
#   - Requires sudo for ending sessions and removing directories
#   - Use --dry-run to preview actions before executing
#   - Only affects sessions with the specified prefix
#
# Examples:
#   # End all trixie-arm64-sbuild sessions
#   ./cleanup_schroot_sessions.sh
#
#   # Preview what would be cleaned up
#   ./cleanup_schroot_sessions.sh --dry-run
#
#   # End sessions and remove leftover directories
#   ./cleanup_schroot_sessions.sh --prune
#
#   # Clean up sessions with a different prefix
#   ./cleanup_schroot_sessions.sh --prefix bookworm-arm64-sbuild
#
set -euo pipefail

SBUILD_CHROOT="trixie-arm64-sbuild"
PRUNE=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: cleanup_schroot_sessions.sh [--prefix NAME] [--prune] [--dry-run]
Ends schroot sessions whose names start with NAME (default: trixie-arm64-sbuild).
--prune removes leftover mount/underlay dirs for those sessions after end-session.
--dry-run prints what would run without making changes.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      SBUILD_CHROOT="${2:-}"
      shift 2
      ;;
    --prune)
      PRUNE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$SBUILD_CHROOT" ]]; then
  echo "ERROR: --prefix is required and cannot be empty." >&2
  exit 2
fi

mapfile -t sessions < <(schroot --list --all-sessions | sed -n 's/^session://p')

selected=()
for s in "${sessions[@]}"; do
  if [[ "$s" == "$SBUILD_CHROOT"* ]]; then
    selected+=("$s")
  fi
done

if [[ ${#selected[@]} -eq 0 ]]; then
  echo "No matching sessions for prefix: $SBUILD_CHROOT"
  exit 0
fi

echo "Ending ${#selected[@]} session(s) with prefix: $SBUILD_CHROOT"
for s in "${selected[@]}"; do
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "sudo schroot --end-session -c $s"
  else
    if ! sudo schroot --end-session -c "$s"; then
      echo "WARN: failed to end session: $s" >&2
    fi
  fi
done

if [[ "$PRUNE" -eq 1 ]]; then
  for s in "${selected[@]}"; do
    for p in "/run/schroot/mount/$s" "/var/lib/schroot/union/underlay/$s"; do
      if [[ -e "$p" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
          echo "sudo rm -rf $p"
        else
          sudo rm -rf "$p"
        fi
      fi
    done
  done
fi
