#!/usr/bin/env bash
# s3_backup.sh
#
# Purpose:
#   Backs up the local ROS 2 Jazzy apt repository to AWS S3 for disaster recovery
#   and redundancy. This script maintains two separate S3 backups with different
#   retention strategies.
#
# Why this is needed:
#   - Provides off-site backup of built Debian packages
#   - Protects against local storage failures, corruption, or data loss
#   - Preserves historical package versions for rollback capability
#   - Maintains a clean snapshot of current repository state
#
# What it does:
#   1. Validates local repository structure and Release files
#   2. Backs up two directories with different strategies:
#
#      a) aptrepo-pages (APPEND-ONLY, NO DELETE)
#         - Published archive with full package history
#         - Never deletes files from S3 (preserves all versions)
#         - Allows recovery of any previously built package
#         - Storage class: STANDARD_IA (infrequent access)
#
#      b) aptrepo (MIRROR WITH DELETE)
#         - Canonical repository snapshot of current state
#         - Mirrors exact state of local repo (removes obsolete files)
#         - Used for restoring a clean, current repository
#         - Storage class: STANDARD_IA (infrequent access)
#
#   3. Verifies backup succeeded by checking for Release file in S3
#
# Backup Architecture:
#   Local                              S3 (Backup)
#   ─────────────────────────────────────────────────────────────
#   /srv/aptrepo/             sync→   s3://[s3-bucket]/aptrepo/
#   (canonical, with --delete)         (clean current snapshot)
#
#   /srv/aptrepo-pages/       sync→   s3://[s3-bucket]/aptrepo-pages/
#   (published, append-only)           (historical archive)
#
# Safety features:
#   - File locking prevents concurrent backup runs
#   - Sanity checks validate repository structure before upload
#   - DRY_RUN=true environment variable for testing
#   - --exact-timestamps ensures correct file versioning
#   - --only-show-errors reduces noise in logs
#
# Usage:
#   # Normal backup
#   ./s3_backup_repo.sh
#
#   # Dry run (preview without making changes)
#   DRY_RUN=true ./s3_backup_repo.sh
#
# Requirements:
#   - AWS CLI installed and configured with valid credentials
#   - Read access to /srv/aptrepo and /srv/aptrepo-pages
#   - Write permissions to s3://[s3-bucket] bucket
#   - flock command (for locking)
#
# Typically called:
#   - After building and publishing packages locally
#   - Via cron jobs for periodic backups
#   - Manually after significant package updates
#
set -euo pipefail

# ----------------- CONFIG -----------------
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.env.sh"; load_env

# Storage classes
S3_PAGES_CLASS="STANDARD_IA"   # published archive
S3_CANONICAL_CLASS="STANDARD_IA"  # rebuild cache

DRY_RUN="${DRY_RUN:-false}"

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }
log() { printf "[%s] %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*"; }
die() { log "ERROR: $*"; exit 1; }

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY_RUN: $*"
  else
    eval "$@"
  fi
}

# Prevent concurrent publishes
LOCKFILE="/tmp/rospian-aptrepo-backup-s3.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  die "Another backup appears to be running (lock: $LOCKFILE)"
fi

need_cmd aws

# ----------------- SANITY CHECKS -----------------
[[ -d "$APTREPO" ]] || die "Canonical repo dir not found: $APTREPO"
[[ -d "$PAGES_DIR" ]] || die "Pages dir not found: $PAGES_DIR"

SUITE_DIR="$APTREPO/dists/$REPO_DIST"
[[ -d "$SUITE_DIR" ]] || die "Suite not found: $SUITE_DIR"
[[ -d "$APTREPO/pool" ]] || die "Missing pool: $APTREPO/pool"

[[ -f "$SUITE_DIR/InRelease" ]] || die "Missing InRelease: $SUITE_DIR/InRelease"
[[ -f "$SUITE_DIR/Release" ]] || die "Missing Release: $SUITE_DIR/Release"

log "Sanity checks OK."

# ----------------- BACKUP TO S3 -----------------

### 1) BACKUP PUBLISHED ARCHIVE (SAFE, APPEND-ONLY)
log "Backing up aptrepo-pages to S3 (archive, no delete)"
run "aws s3 sync '$PAGES_DIR' 's3://$S3_BUCKET/$S3_PAGES_PREFIX/' \
  --exact-timestamps \
  --only-show-errors \
  --storage-class $S3_PAGES_CLASS"

log "aptrepo-pages backup complete."

### 2) BACKUP CANONICAL REPO (MIRROR SNAPSHOT, WITH DELETE)
log "Backing up aptrepo (canonical) to S3 (mirror with delete)"
run "aws s3 sync '$APTREPO' 's3://$S3_BUCKET/$S3_CANONICAL_PREFIX/' \
  --delete \
  --exact-timestamps \
  --only-show-errors \
  --storage-class $S3_CANONICAL_CLASS"

log "aptrepo (canonical) backup complete."

log "Publish + backup completed successfully."

log "Verifying S3 Release file presence"
run "aws s3 ls s3://$S3_BUCKET/$S3_PAGES_PREFIX/dists/$REPO_DIST/Release"
