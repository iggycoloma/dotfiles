#!/usr/bin/env bash
# Push notification when Claude Code is idle and waiting for input.
# Reads hook JSON from stdin; sends push via Pushover.

LIB="$(dirname "$0")/notify-pushover.sh"
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
