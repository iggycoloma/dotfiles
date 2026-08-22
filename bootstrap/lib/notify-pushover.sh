# shellcheck shell=bash
# notify-pushover.sh -- shared Pushover notification helpers.
#
# Sourced (not executed) by the per-tool notify hooks (claude-code/hooks/notify.sh,
# codex/hooks/notify.sh). Deployed to ~/.claude/hooks/ and ~/.codex/hooks/ by
# bootstrap/symlinks.sh so the hooks can source a sibling file:
#
#   LIB="$(dirname "$0")/notify-pushover.sh"
#   [[ -f "$LIB" ]] || exit 0
#   # shellcheck source=/dev/null
#   source "$LIB"
#
# Public functions:
#   _pushover_resolve_creds [creds_file]  -- read missing creds from file; sets/uses
#                                            APP_TOKEN and PUSHOVER_USER globals.
#                                            Returns 0 iff both are set.
#   notify_session_label INPUT ENV_VAR ID_FIELD  -- derive a label from JSON input,
#                                            with env-var override and a JSON field
#                                            name for the session/thread id.
#   send_pushover TITLE MESSAGE          -- fire-and-forget POST to Pushover.

CREDS_FILE_DEFAULT="$HOME/.claude/hooks/.pushover-creds"

_pushover_resolve_creds() {
    local creds_file="${1:-$CREDS_FILE_DEFAULT}"
    if [[ -z "$APP_TOKEN" || -z "$PUSHOVER_USER" ]] && [[ -f "$creds_file" ]]; then
        [[ -z "$APP_TOKEN" ]] && APP_TOKEN=$(sed -n '1p' "$creds_file")
        [[ -z "$PUSHOVER_USER" ]] && PUSHOVER_USER=$(sed -n '2p' "$creds_file")
    fi
    [[ -n "$APP_TOKEN" && -n "$PUSHOVER_USER" ]]
}

notify_session_label() {
    local input="$1" env_var="$2" id_field="$3"
    local override="${!env_var:-}"
    if [[ -n "$override" ]]; then
        printf '%s' "$override"
        return
    fi

    local cwd project branch session_id
    cwd=$(echo "$input" | grep -o '"cwd":"[^"]*"' | head -1 | cut -d'"' -f4)
    project="${cwd##*/}"
    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

    if [[ -n "$project" && -n "$branch" ]]; then
        printf '%s (%s)' "$project" "$branch"
    elif [[ -n "$project" ]]; then
        printf '%s' "$project"
    else
        session_id=$(echo "$input" | grep -o "\"$id_field\":\"[^\"]*\"" | head -1 | cut -d'"' -f4)
        printf 'session %s' "${session_id:0:6}"
    fi
}

send_pushover() {
    local title="$1" message="$2"
    curl -s \
        -F "token=$APP_TOKEN" \
        -F "user=$PUSHOVER_USER" \
        -F "title=$title" \
        -F "message=$message" \
        -F "priority=1" \
        -F "sound=cosmic" \
        https://api.pushover.net/1/messages.json &>/dev/null &
}
