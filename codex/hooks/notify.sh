#!/usr/bin/env bash
# Push notification when Codex CLI is idle and waiting for input.
# Receives hook JSON as $1 (command-line argument); sends push via Pushover.

# --- Credentials: env vars > creds file ---
CREDS_FILE="$HOME/.claude/hooks/.pushover-creds"

APP_TOKEN="${PUSHOVER_APP_TOKEN_CODEX:-$PUSHOVER_TOKEN}"

if [[ -z "$APP_TOKEN" || -z "$PUSHOVER_USER" ]] && [[ -f "$CREDS_FILE" ]]; then
    [[ -z "$APP_TOKEN" ]] && APP_TOKEN=$(sed -n '1p' "$CREDS_FILE")
    [[ -z "$PUSHOVER_USER" ]] && PUSHOVER_USER=$(sed -n '2p' "$CREDS_FILE")
fi

if [[ -z "$APP_TOKEN" || -z "$PUSHOVER_USER" ]]; then
    exit 0
fi

INPUT="$1"

# --- Session label: env override > cwd + git branch > cwd > thread id ---
if [[ -n "$CODEX_SESSION_NAME" ]]; then
    LABEL="$CODEX_SESSION_NAME"
else
    CWD=$(echo "$INPUT" | grep -o '"cwd":"[^"]*"' | head -1 | cut -d'"' -f4)
    PROJECT="${CWD##*/}"
    BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ -n "$PROJECT" && -n "$BRANCH" ]]; then
        LABEL="$PROJECT ($BRANCH)"
    elif [[ -n "$PROJECT" ]]; then
        LABEL="$PROJECT"
    else
        THREAD_ID=$(echo "$INPUT" | grep -o '"thread-id":"[^"]*"' | head -1 | cut -d'"' -f4)
        LABEL="session ${THREAD_ID:0:6}"
    fi
fi

TITLE="Codex"
MESSAGE="$LABEL ready for input"

# --- Pushover push notification ---
curl -s \
  -F "token=$APP_TOKEN" \
  -F "user=$PUSHOVER_USER" \
  -F "title=$TITLE" \
  -F "message=$MESSAGE" \
  -F "priority=1" \
  -F "sound=cosmic" \
  https://api.pushover.net/1/messages.json &>/dev/null &

exit 0
