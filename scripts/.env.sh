load_env() {
    local scripts_dir root
    scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    root="$(cd "$scripts_dir/.." && pwd)"

    local base="${1:-$root/.env}"
    local localf="${2:-$root/.env.local}"

    # Save current allexport state
    local old_allexport
    old_allexport="$(set +o | grep allexport)"

    set -a
    [ -f "$base" ]   && source "$base"
    [ -f "$localf" ] && source "$localf"

    # Restore previous state
    eval "$old_allexport"
}
