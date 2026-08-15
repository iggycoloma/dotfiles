#!/usr/bin/env bash
# sync-sandbox-kit.sh -- Generate the sandbox kit's egress allowlist from
# unattended/egress-allowlist.txt.
#
# Two profiles enforce the same boundary by different means: the unattended
# devcontainer routes through mitmproxy, Docker Sandboxes through their own
# host-side proxy. The host list is the same either way, so it is maintained
# once and projected here -- the same reason bin/sync-settings.sh generates the
# container settings variant rather than leaving two files to drift.
#
# Only the marked block is rewritten; the rest of spec.yaml is hand-maintained.
#
# Exit codes:
#   0  block written, or already current under --check
#   1  --check and the committed block is stale
#   2  prerequisite missing or a source file is unreadable

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# shellcheck source=../bootstrap/logging.sh
source "$DOTFILES_DIR/bootstrap/logging.sh"

ALLOWLIST="$DOTFILES_DIR/unattended/egress-allowlist.txt"
SPEC="$DOTFILES_DIR/sandbox/spec.yaml"
BEGIN='    # BEGIN wt-managed egress'
END='    # END wt-managed egress'

CHECK_ONLY=false

usage() {
    cat <<'HELP'
Usage: sync-sandbox-kit.sh [--check]

  --check   Exit 1 if the committed block is stale; write nothing.
HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) CHECK_ONLY=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

for f in "$ALLOWLIST" "$SPEC"; do
    [[ -r "$f" ]] || { log_error "Not readable: $f"; exit 2; }
done

grep -qF "$BEGIN" "$SPEC" || { log_error "Marker not found in $SPEC: $BEGIN"; exit 2; }

# Comments and blanks out, one host per line in, YAML sequence out. The header
# is regenerated with the body so the provenance note cannot outlive the
# generator that wrote it.
render_block() {
    printf '%s -- generated from unattended/egress-allowlist.txt\n' "$BEGIN"
    printf '%s\n' '    # by bin/sync-sandbox-kit.sh. Edits inside this block are overwritten;'
    printf '%s\n' '    # add hosts to the allowlist instead. Anything outside it is preserved.'
    printf '%s\n' '    allow:'
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$ALLOWLIST" |
        grep -v '^$' |
        sort -u |
        sed 's/^/      - /'
    printf '%s\n' "$END"
}

# awk over sed: the replacement is multi-line and contains slashes and dashes,
# which sed's s/// would need escaped in the payload. The block goes through a
# file rather than -v because BSD awk rejects newlines in a -v assignment.
block_file="$(mktemp)"
trap 'rm -f "$block_file"' EXIT
render_block > "$block_file"

new_spec="$(
    awk -v begin="$BEGIN" -v end="$END" -v blockfile="$block_file" '
        index($0, begin) == 1 {
            while ((getline line < blockfile) > 0) print line
            close(blockfile)
            skipping = 1
            next
        }
        index($0, end) == 1 { skipping = 0; next }
        !skipping           { print }
    ' "$SPEC"
)"

if [[ "$new_spec" == "$(cat "$SPEC")" ]]; then
    log_success "Sandbox kit egress block is current"
    exit 0
fi

if [[ "$CHECK_ONLY" == true ]]; then
    log_error "Sandbox kit egress block is stale -- run bin/sync-sandbox-kit.sh"
    exit 1
fi

printf '%s\n' "$new_spec" > "$SPEC"
log_success "Wrote sandbox kit egress block from $(basename "$ALLOWLIST")"
