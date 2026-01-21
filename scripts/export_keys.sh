#!/usr/bin/env bash
set -euo pipefail

# Export Rospian repository GPG keys (public, private, revocation cert)
# Verifies InRelease signature, identifies the signing key, and exports:
#   - Public key (for users to verify packages)
#   - Private key (for backup/recovery - requires secret key access)
#   - Revocation certificate (for key compromise scenarios)
# Must run as root or key owner. Outputs timestamped .asc files.

INRELEASE="${INRELEASE:-$APTREPO/dists/trixie-jazzy/InRelease}"
APT_KEYRING="${APT_KEYRING:-/etc/apt/keyrings/local-ros-repo.gpg}"
OUTDIR="${OUTDIR:-.}"

# Optional: set OWNER=[myuser]:[myuser] to chown outputs after creation
OWNER="${OWNER:-}"

die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

need gpg
need awk
need sed
need mkdir
need chmod
need date

[[ -f "$INRELEASE" ]] || die "InRelease not found: $INRELEASE"
[[ -f "$APT_KEYRING" ]] || die "APT keyring not found: $APT_KEYRING"

ts="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUTDIR"

echo "==> Verifying InRelease..."
verify_out="$(
  gpg --no-default-keyring \
      --keyring "$APT_KEYRING" \
      --verify "$INRELEASE" 2>&1 || true
)"

echo "$verify_out" | sed 's/^/    /'

# Prefer "Primary key fingerprint" if present...
MASTER_FPR="$(
  echo "$verify_out" \
  | awk -F': ' '/^Primary key fingerprint:/{gsub(/ /,"",$2); print $2; exit}'
)"

# ...otherwise fall back to extracting the signing key id and resolving its fingerprint from the APT keyring.
if [[ -z "${MASTER_FPR:-}" ]]; then
  KEYID="$(
    echo "$verify_out" \
    | awk '/using (RSA|DSA|EDDSA|ECDSA) key /{print $NF; exit}' \
    | sed 's/[^0-9A-Fa-f]//g'
  )"

  [[ -n "${KEYID:-}" ]] || die "Could not extract signer key id from gpg --verify output."

  # Resolve fingerprint for that key id from the *same* keyring used to verify.
  MASTER_FPR="$(
    gpg --no-default-keyring \
        --keyring "$APT_KEYRING" \
        --with-colons --fingerprint --list-keys "$KEYID" 2>/dev/null \
    | awk -F: '$1=="fpr"{print $10; exit}'
  )"

  [[ -n "${MASTER_FPR:-}" ]] || die "Could not resolve fingerprint for key id '$KEYID' from APT keyring."
fi

echo "==> Active primary fingerprint (from APT trust keyring): $MASTER_FPR"
echo

pub_asc="$OUTDIR/rospian-archive-public.${MASTER_FPR}.${ts}.asc"
priv_asc="$OUTDIR/rospian-archive-private.${MASTER_FPR}.${ts}.asc"
revoke_asc="$OUTDIR/rospian-archive-revocation.${MASTER_FPR}.${ts}.asc"

echo "==> Exporting public key to: $pub_asc"
gpg --export --armor "$MASTER_FPR" > "$pub_asc"

echo "==> Exporting private (secret) key to: $priv_asc"
# This requires the secret key to exist in the current user's GPG home (root, in your case).
gpg --export-secret-keys --armor "$MASTER_FPR" > "$priv_asc" \
  || die "Secret key export failed. Run as the key owner (likely: sudo bash export_keys.sh)."

echo "==> Generating revocation certificate to: $revoke_asc"
# Interactive by design (prevents accidental revoke creation/overwrite).
gpg --output "$revoke_asc" --gen-revoke "$MASTER_FPR"

chmod 0644 "$pub_asc"
chmod 0600 "$priv_asc" "$revoke_asc"

if [[ -n "$OWNER" ]]; then
  echo "==> Setting ownership to: $OWNER"
  chown "$OWNER" "$pub_asc" "$priv_asc" "$revoke_asc"
fi

cat <<EOF

Done.

Files created:
  Public:     $pub_asc
  Private:    $priv_asc
  Revocation: $revoke_asc

Notes:
- Revocation generation is interactive by design.
- Private + revocation files are chmod 0600.
- Fingerprint is derived from the same APT keyring used for verification:
    $APT_KEYRING

EOF
