#!/usr/bin/env bash
set -euo pipefail

# Backup rospian key artifacts (*.asc) to S3 with SSE-S3 (AES256), no KMS.
# Usage:
#   ./s3_backup_keys.sh
#   DRY_RUN=true ./s3_backup_keys.sh

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.env.sh"; load_env

KEY_DIR="${KEY_DIR:-.}"                    # directory containing rospian-archive-*.asc
DRY_RUN="${DRY_RUN:-false}"

die() { echo "ERROR: $*" >&2; exit 1; }

command -v aws >/dev/null 2>&1 || die "aws CLI not found"
[[ -d "$KEY_DIR" ]] || die "KEY_DIR not found: $KEY_DIR"

# Ensure there is something to upload
shopt -s nullglob
files=( "$KEY_DIR"/rospian-archive-*.asc )
shopt -u nullglob
(( ${#files[@]} > 0 )) || die "No key files found matching: $KEY_DIR/rospian-archive-*.asc"

S3_URI="s3://${S3_SECRETS_BUCKET}/${S3_PREFIX_BUCKET}"

echo "==> Backing up key files to: $S3_URI"
echo "==> Source directory: $KEY_DIR"
echo "==> Files:"
for f in "${files[@]}"; do
  echo "    - $(basename "$f")"
done
echo

AWS_EXTRA_ARGS=()
if [[ "$DRY_RUN" == "true" ]]; then
  AWS_EXTRA_ARGS+=(--dryrun)
  echo "==> DRY RUN (no changes will be made)"
fi

# Upload only rospian-archive-*.asc, encrypted at rest with SSE-S3 (AES256)
aws s3 cp "$KEY_DIR" "$S3_URI" \
  --recursive \
  --exclude "*" \
  --include "rospian-archive-*.asc" \
  --sse AES256 \
  "${AWS_EXTRA_ARGS[@]}"

echo
echo "==> Upload complete. Listing destination:"
aws s3 ls "$S3_URI"

echo
echo "==> (Optional) Verify encryption on one object:"
echo "    aws s3api head-object --bucket ${S3_SECRETS_BUCKET} --key ${S3_PREFIX_BUCKET}rospian-archive-private.<...>.asc"
