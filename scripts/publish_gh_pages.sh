#!/usr/bin/env bash
set -euo pipefail

# Publish the local reprepro snapshot to GitHub Pages.
# Assumes the apt repo is already exported in $APTREPO and that $PAGES_DIR
# is a working tree for the gh-pages branch (will be created/overwritten).
# Requires git and rsync; will force-push to $PAGES_GIT_URL/$PAGES_GIT_BRANCH.

# ===== CONFIG =====
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.env.sh"; load_env

VERIFY=0
VERIFY_ONLY=0

usage() {
  cat <<'EOF'
Usage: publish_gh_pages.sh [--verify] [--verify-only]

  --verify       Run local repo verification after publishing.
  --verify-only  Only verify the existing publish snapshot.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --verify)
      VERIFY=1
      ;;
    --verify-only)
      VERIFY=1
      VERIFY_ONLY=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# ===== SANITY CHECKS =====
for d in dists pool public; do
  if [ ! -d "$APTREPO/$d" ]; then
    echo "ERROR: $APTREPO/$d does not exist"
    exit 1
  fi
done

# ===== PREPARE PUBLISH DIR =====
mkdir -p "$PAGES_DIR"
cd "$PAGES_DIR"

if [ ! -d .git ]; then
  echo "== Initialising publish repo"
  git init
  git checkout --orphan "$PAGES_GIT_BRANCH"
  git remote add origin "$PAGES_GIT_URL"
else
  git fetch origin || true
  if git show-ref --verify --quiet "refs/heads/$PAGES_GIT_BRANCH"; then
    git checkout "$PAGES_GIT_BRANCH"
  else
    git checkout --orphan "$PAGES_GIT_BRANCH"
  fi
fi

verify_publish_snapshot() {
  local list_dir
  local cache_dir

  echo "== Verifying publish snapshot"
  for suite_dir in "$PAGES_DIR"/dists/*; do
    if [ ! -d "$suite_dir" ]; then
      continue
    fi
    if [ -f "$suite_dir/InRelease" ]; then
      gpg --verify "$suite_dir/InRelease"
    fi
    if [ -f "$suite_dir/Release" ] && [ -f "$suite_dir/Release.gpg" ]; then
      gpg --verify "$suite_dir/Release.gpg" "$suite_dir/Release"
    fi
  done

  list_dir=$(mktemp -d /tmp/apt-lists-test.XXXXXX)
  cache_dir=$(mktemp -d /tmp/apt-archives-test.XXXXXX)
  mkdir -p "$list_dir/partial" "$cache_dir/partial"

  apt-get -o Dir::Etc::sourcelist=/dev/null \
    -o Dir::Etc::sourceparts=/dev/null \
    -o Acquire::AllowInsecureRepositories=true \
    -o Acquire::AllowDowngradeToInsecureRepositories=true \
    -o Dir::Etc::trusted=/dev/null \
    -o Dir::Etc::trustedparts=/dev/null \
    -o Dir::State::Lists="$list_dir" \
    -o Dir::Cache::Archives="$cache_dir" \
    update -o Dir::Etc::sourcelist=<(echo "deb [trusted=yes] file:$PAGES_DIR trixie-jazzy main")
}

if [ "$VERIFY_ONLY" -eq 1 ]; then
  verify_publish_snapshot
  exit 0
fi

# ===== WIPE TRACKED CONTENT =====
git rm -rf . >/dev/null 2>&1 || true

# ===== COPY CURRENT SNAPSHOT =====
echo "== Copying APT repo snapshot"
rsync -a --delete \
  --exclude='*dbgsym*.deb' \
  "$APTREPO/dists" \
  "$APTREPO/public" \
  ./
  
rsync -a \
  --exclude='*dbgsym*.deb' \
  "$APTREPO/pool" \
  ./

# ===== CLEAN DEBUG SYMBOLS =====
echo "== Removing dbgsym packages from publish snapshot"
SIGN_WITH=""
if [ -f "$APTREPO/conf/distributions" ]; then
  SIGN_WITH=$(awk -F': ' '/^SignWith:/ {print $2; exit}' "$APTREPO/conf/distributions")
fi

filter_dbgsym_packages() {
  local pkg_file="$1"

  if ! grep -q 'dbgsym' "$pkg_file"; then
    return 1
  fi

  awk 'BEGIN{RS=""; ORS="\n\n"} {
    keep=1
    for (i=1; i<=NF; i++) {
      if ($i ~ /^Package: .*dbgsym/ || $i ~ /^Filename: .*dbgsym/) {
        keep=0
        break
      }
    }
    if (keep) print $0
  }' "$pkg_file" > "${pkg_file}.tmp"
  mv "${pkg_file}.tmp" "$pkg_file"

  if [ -f "${pkg_file}.gz" ]; then
    gzip -9 -c "$pkg_file" > "${pkg_file}.gz"
  fi
  if [ -f "${pkg_file}.xz" ]; then
    xz -9 -c "$pkg_file" > "${pkg_file}.xz"
  fi

  return 0
}

update_release() {
  local suite_dir="$1"
  local release_file="$suite_dir/Release"
  local header_file
  local -a rel_files=()

  if [ -z "$SIGN_WITH" ]; then
    echo "ERROR: SignWith key not found in $APTREPO/conf/distributions" >&2
    exit 1
  fi

  header_file=$(mktemp)
  awk -v date="$(date -Ru)" '
    /^MD5Sum:/{exit}
    /^Date:/{print "Date: " date; next}
    {print}
  ' "$release_file" > "$header_file"

  while IFS= read -r -d '' file; do
    case "$file" in
      "$suite_dir/Release"|"$suite_dir/InRelease"|"$suite_dir/Release.gpg")
        continue
        ;;
    esac
    rel_files+=( "${file#$suite_dir/}" )
  done < <(find "$suite_dir" -type f -print0 | LC_ALL=C sort -z)

  {
    cat "$header_file"
    echo "MD5Sum:"
    for rel in "${rel_files[@]}"; do
      printf " %s %s %s\n" \
        "$(md5sum "$suite_dir/$rel" | awk '{print $1}')" \
        "$(stat -c%s "$suite_dir/$rel")" \
        "$rel"
    done
    echo "SHA1:"
    for rel in "${rel_files[@]}"; do
      printf " %s %s %s\n" \
        "$(sha1sum "$suite_dir/$rel" | awk '{print $1}')" \
        "$(stat -c%s "$suite_dir/$rel")" \
        "$rel"
    done
    echo "SHA256:"
    for rel in "${rel_files[@]}"; do
      printf " %s %s %s\n" \
        "$(sha256sum "$suite_dir/$rel" | awk '{print $1}')" \
        "$(stat -c%s "$suite_dir/$rel")" \
        "$rel"
    done
  } > "${release_file}.tmp"
  mv "${release_file}.tmp" "$release_file"
  rm -f "$header_file"

  gpg --batch --yes --default-key "$SIGN_WITH" \
    --clearsign -o "$suite_dir/InRelease" "$release_file"
  gpg --batch --yes --default-key "$SIGN_WITH" \
    -abs -o "$suite_dir/Release.gpg" "$release_file"
}

for suite_dir in "$PAGES_DIR"/dists/*; do
  if [ ! -d "$suite_dir" ]; then
    continue
  fi

  suite_changed=0
  while IFS= read -r -d '' pkg_file; do
    if filter_dbgsym_packages "$pkg_file"; then
      suite_changed=1
    fi
  done < <(find "$suite_dir" -type f -path "*/binary-*/Packages" -print0)

  if [ "$suite_changed" -eq 1 ]; then
    update_release "$suite_dir"
  fi
done

if [ "$VERIFY" -eq 1 ]; then
  verify_publish_snapshot
fi

# ===== COMMIT & FORCE PUSH =====
git add -A
git commit -m "APT repo snapshot $(date -u +%Y-%m-%dT%H:%M:%SZ)"

git push -f origin "$PAGES_GIT_BRANCH"

echo "== Publish complete"
