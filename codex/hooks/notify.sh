#!/usr/bin/env bash
# Push notification when Codex CLI is idle and waiting for input.
# Receives hook JSON as $1; sends push via Pushover.

LIB="$(dirname "$0")/notify-pushover.sh"
[[ -f "$LIB" ]] || exit 0
# shellcheck source=../../bootstrap/lib/notify-pushover.sh
source "$LIB"

# APP_TOKEN and PUSHOVER_USER are read by _pushover_resolve_creds.
# shellcheck disable=SC2034
APP_TOKEN="${PUSHOVER_APP_TOKEN_CODEX:-$PUSHOVER_TOKEN}"
_pushover_resolve_creds || exit 0

LABEL=$(notify_session_label "$1" CODEX_SESSION_NAME thread-id)
send_pushover "Codex" "$LABEL ready for input"
exit 0
