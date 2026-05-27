#!/usr/bin/env bash
# Push notification when Claude Code is idle and waiting for input.
# Reads hook JSON from stdin; sends push via Pushover.

# Resolve the pushover lib by walking symlinks back to the real script
# location. On hosts the hook is a symlink into the dotfiles repo, so
# the lib lives at <repo>/bootstrap/lib/. In devcontainers the hook is
# a real copy with the lib deployed as a sibling.
_resolve_self() {
    local s="${BASH_SOURCE[0]}"
    while [[ -L "$s" ]]; do
        local d
        d="$(cd "$(dirname "$s")" && pwd)"
        s="$(readlink "$s")"
        [[ "$s" != /* ]] && s="$d/$s"
    done
    cd "$(dirname "$s")" && pwd
}
SELF_DIR="$(_resolve_self)"
LIB="$SELF_DIR/../../bootstrap/lib/notify-pushover.sh"
[[ -f "$LIB" ]] || LIB="$(dirname "$0")/notify-pushover.sh"
[[ -f "$LIB" ]] || exit 0
# shellcheck source=../../bootstrap/lib/notify-pushover.sh
source "$LIB"

# APP_TOKEN and PUSHOVER_USER are read by _pushover_resolve_creds.
# shellcheck disable=SC2034
APP_TOKEN="${PUSHOVER_APP_TOKEN_CLAUDE:-$PUSHOVER_TOKEN}"
_pushover_resolve_creds || exit 0

INPUT=$(cat)
LABEL=$(notify_session_label "$INPUT" CLAUDE_SESSION_NAME session_id)
send_pushover "Claude Code" "$LABEL ready for input"
exit 0
