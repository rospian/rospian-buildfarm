#!/usr/bin/env bash
# s3_restore.sh
#
# Purpose:
#   Restores the ROS 2 Jazzy apt repository from AWS S3 backups to local storage.
#   This script recovers both the published repository (with git history) and the
#   canonical build cache from S3, enabling disaster recovery or migration to a
#   new build server.
#
# Why this is needed:
#   - Disaster recovery: Restore after storage failure or system crash
#   - Migration: Set up repository on a new build server
#   - Rollback: Recover from accidental local deletions or corruption
#   - Testing: Create a clean repository copy for validation
#
# What it does:
#   1. Validates S3 bucket and prefixes are accessible
#   2. Restores two directories with different strategies:
#
#      a) /srv/aptrepo-pages (GIT-TRACKED)
#         - Clones or updates gh-pages branch from GitHub
#         - Syncs published content (dists/, pool/) from S3 into working tree
#         - Preserves .git directory for version control
#         - Restores stamp files (ROSPIAN_RELEASED_AT.txt, etc.) if present
#
#      b) /srv/aptrepo (MIRROR FROM S3)
#         - Syncs canonical repository snapshot from S3
#         - Default: mirrors exactly with --delete (MIRROR_CANONICAL=true)
#         - Optional: append-only sync without --delete
#         - Used for rebuilding packages with existing dependencies
#
#   3. Verifies restored structures (Release files, pool/, dists/)
#
# Restore Architecture:
#   S3 (Backup)                        Local
#   ─────────────────────────────────────────────────────────────
#   s3://[s3-bucket]/aptrepo-pages/  sync→ /srv/aptrepo-pages/
#   (historical archive)                (git working tree + S3 content)
#
#   s3://[s3-bucket]/aptrepo/        sync→ /srv/aptrepo/
#   (clean snapshot)                    (canonical, mirrored with --delete)
#
# Safety features:
#   - File locking prevents concurrent restore operations
#   - Checks for non-empty directories before overwriting
#   - FORCE=true required to overwrite existing content
#   - Validates git working tree is clean before updating
#   - DRY_RUN=true environment variable for testing
#   - Post-restore verification checks for critical files
#
# Environment Variables:
#   FORCE=true           - Allow overwriting non-empty directories
#   MIRROR_CANONICAL=true  - Use --delete for /srv/aptrepo (default: true)
#   MIRROR_CANONICAL=false - Append-only sync for /srv/aptrepo
#   DRY_RUN=true         - Preview actions without making changes
#   PAGES_GIT_URL=<url>  - Override GitHub pages repository URL
#
# Usage:
#   # Normal restore (will fail if directories exist and are non-empty)
#   ./s3_restore.sh
#
#   # Force restore, overwriting existing content
#   FORCE=true ./s3_restore.sh
#
#   # Dry run to preview actions
#   DRY_RUN=true ./s3_restore_repo.sh
#
#   # Restore canonical without deleting local extras
#   MIRROR_CANONICAL=false ./s3_restore_repo.sh
#
# Requirements:
#   - AWS CLI installed and configured with valid credentials
#   - Git installed and SSH key configured for GitHub access
#   - Write permissions to /srv/aptrepo and /srv/aptrepo-pages
#   - Read permissions to s3://[s3-bucket] bucket
#   - flock command (for locking)
#
# Common scenarios:
#   - New server setup: Run with empty /srv directories
#   - After corruption: Run with FORCE=true to replace damaged files
#   - Regular sync: Run periodically to keep local copy current
#
set -euo pipefail

# ----------------- CONFIG -----------------
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.env.sh"; load_env

# Safety / behavior toggles
FORCE="${FORCE:-false}"                       # allow overwriting non-empty target dirs
MIRROR_CANONICAL="${MIRROR_CANONICAL:-true}"  # delete local extras to mirror S3 for /srv/aptrepo
DRY_RUN="${DRY_RUN:-false}"
# ------------------------------------------

log() { printf "[%s] %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*"; }
die() { log "ERROR: $*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY_RUN: $*"
  else
    eval "$@"
  fi
}

need_cmd aws
need_cmd git

LOCKFILE="/tmp/rospian-aptrepo-restore-gitfirst.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  die "Another restore appears to be running (lock: $LOCKFILE)"
fi

is_dir_empty() {
  local d="$1"
  [[ -d "$d" ]] || return 0
  shopt -s nullglob dotglob
  local files=("$d"/*)
  shopt -u nullglob dotglob
  [[ ${#files[@]} -eq 0 ]]
}

ensure_empty_or_force() {
  local d="$1"
  if [[ -d "$d" ]] && ! is_dir_empty "$d"; then
    if [[ "$FORCE" != "true" ]]; then
      die "Target directory is not empty: $d (set FORCE=true to override)"
    else
      log "FORCE=true: proceeding even though $d is not empty"
    fi
  fi
}

# ----------------- PRECHECK S3 -----------------
log "Checking S3 prefixes exist"
run "aws s3 ls 's3://$S3_BUCKET/$S3_PAGES_PREFIX/' >/dev/null"
run "aws s3 ls 's3://$S3_BUCKET/$S3_CANONICAL_PREFIX/' >/dev/null"
log "S3 reachable."

# ----------------- RESTORE /srv/aptrepo-pages as gh-pages checkout -----------------
log "Preparing gh-pages checkout at $PAGES_DIR"
log "Using pages repo URL: $PAGES_GIT_URL"

if [[ -d "$PAGES_DIR/.git" ]]; then
  log "Existing git repo detected in $PAGES_DIR"

  if [[ "$DRY_RUN" != "true" && "$FORCE" != "true" ]]; then
    if [[ -n "$(git -C "$PAGES_DIR" status --porcelain)" ]]; then
      die "Pages repo has local modifications. Commit/stash or rerun with FORCE=true."
    fi
  fi

  run "git -C '$PAGES_DIR' fetch origin"
  run "git -C '$PAGES_DIR' checkout '$GIT_BRANCH'"
  run "git -C '$PAGES_DIR' pull --ff-only origin '$GIT_BRANCH'"
else
  if [[ -d "$PAGES_DIR" ]] && ! is_dir_empty "$PAGES_DIR"; then
    ensure_empty_or_force "$PAGES_DIR"
    if [[ "$FORCE" == "true" && "$DRY_RUN" != "true" ]]; then
      log "FORCE=true: removing existing contents of $PAGES_DIR"
      rm -rf "${PAGES_DIR:?}/"*
    fi
  fi

  run "mkdir -p '$PAGES_DIR'"
  log "Cloning branch $GIT_BRANCH into $PAGES_DIR"
  run "git clone --branch '$GIT_BRANCH' --single-branch '$PAGES_GIT_URL' '$PAGES_DIR'"
fi

# Restore published content from S3 into working tree (keep .git pristine)
log "Restoring published content (dists/, pool/, stamps) from S3 into gh-pages working tree"

run "aws s3 sync 's3://$S3_BUCKET/$S3_PAGES_PREFIX/dists/' '$PAGES_DIR/dists/' --exact-timestamps --only-show-errors"
run "aws s3 sync 's3://$S3_BUCKET/$S3_PAGES_PREFIX/pool/'  '$PAGES_DIR/pool/'  --exact-timestamps --only-show-errors"

# Optional small stamp files (ignore if absent in S3)
for f in ROSPIAN_RELEASED_AT.txt Release.sha256 DEBLINE.txt; do
  if aws s3 ls "s3://$S3_BUCKET/$S3_PAGES_PREFIX/$f" >/dev/null 2>&1; then
    run "aws s3 cp 's3://$S3_BUCKET/$S3_PAGES_PREFIX/$f' '$PAGES_DIR/$f' --only-show-errors"
  fi
done

# ----------------- RESTORE /srv/aptrepo (canonical) -----------------
log "Restoring canonical repo to $APTREPO"
run "mkdir -p '$APTREPO'"

if [[ -d "$APTREPO" ]] && ! is_dir_empty "$APTREPO"; then
  ensure_empty_or_force "$APTREPO"
fi

if [[ "$MIRROR_CANONICAL" == "true" ]]; then
  run "aws s3 sync 's3://$S3_BUCKET/$S3_CANONICAL_PREFIX/' '$APTREPO/' --delete --exact-timestamps --only-show-errors"
else
  run "aws s3 sync 's3://$S3_BUCKET/$S3_CANONICAL_PREFIX/' '$APTREPO/' --exact-timestamps --only-show-errors"
fi

# ----------------- POST-RESTORE VERIFICATION -----------------
log "Verifying restored structures"

[[ -d "$PAGES_DIR/dists/$REPO_DIST" ]] || die "Missing $PAGES_DIR/dists/$REPO_DIST"
[[ -d "$PAGES_DIR/pool" ]] || die "Missing $PAGES_DIR/pool"
[[ -f "$PAGES_DIR/dists/$REPO_DIST/Release" ]] || die "Missing $PAGES_DIR/dists/$REPO_DIST/Release"
if [[ ! -f "$PAGES_DIR/dists/$REPO_DIST/InRelease" && ! -f "$PAGES_DIR/dists/$REPO_DIST/Release.gpg" ]]; then
  die "Missing InRelease/Release.gpg in $PAGES_DIR/dists/$REPO_DIST"
fi

[[ -d "$APTREPO/dists/$REPO_DIST" ]] || die "Missing $APTREPO/dists/$REPO_DIST"
[[ -d "$APTREPO/pool" ]] || die "Missing $APTREPO/pool"
[[ -f "$APTREPO/dists/$REPO_DIST/Release" ]] || die "Missing $APTREPO/dists/$REPO_DIST/Release"

log "Restore verification OK."
log "Restore completed successfully."
