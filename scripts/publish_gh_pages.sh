#!/usr/bin/env bash
set -euo pipefail

# Publish the local reprepro snapshot to GitHub Pages.
# Assumes the apt repo is already exported in $APT_REPO and that $PUBLISH_DIR
# is a working tree for the gh-pages branch (will be created/overwritten).
# Requires git and rsync; will force-push to $REMOTE/$BRANCH.

# ===== CONFIG =====
APT_REPO="/srv/aptrepo"
PUBLISH_DIR="/srv/aptrepo-pages"
REMOTE="git@github.com:rospian/rospian-repo.git"
BRANCH="gh-pages"

# ===== SANITY CHECKS =====
for d in dists pool public; do
  if [ ! -d "$APT_REPO/$d" ]; then
    echo "ERROR: $APT_REPO/$d does not exist"
    exit 1
  fi
done

# ===== PREPARE PUBLISH DIR =====
mkdir -p "$PUBLISH_DIR"
cd "$PUBLISH_DIR"

if [ ! -d .git ]; then
  echo "== Initialising publish repo"
  git init
  git checkout --orphan "$BRANCH"
  git remote add origin "$REMOTE"
else
  git fetch origin || true
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git checkout "$BRANCH"
  else
    git checkout --orphan "$BRANCH"
  fi
fi

# ===== WIPE TRACKED CONTENT =====
git rm -rf . >/dev/null 2>&1 || true

# ===== COPY CURRENT SNAPSHOT =====
echo "== Copying APT repo snapshot"
rsync -a --delete \
  "$APT_REPO/dists" \
  "$APT_REPO/pool" \
  "$APT_REPO/public" \
  ./

# ===== COMMIT & FORCE PUSH =====
git add -A
git commit -m "APT repo snapshot $(date -u +%Y-%m-%dT%H:%M:%SZ)"

git push -f origin "$BRANCH"

echo "== Publish complete"
