#!/usr/bin/env bash
# Push notification when Claude Code is idle and waiting for input.
# Reads hook JSON from stdin; sends push via Pushover.

# --- Credentials: env vars > creds file ---
CREDS_FILE="$HOME/.claude/hooks/.pushover-creds"

if [[ -z "$PUSHOVER_TOKEN" || -z "$PUSHOVER_USER" ]] && [[ -f "$CREDS_FILE" ]]; then
    PUSHOVER_TOKEN=$(sed -n '1p' "$CREDS_FILE")
    PUSHOVER_USER=$(sed -n '2p' "$CREDS_FILE")
fi

if [[ -z "$PUSHOVER_TOKEN" || -z "$PUSHOVER_USER" ]]; then
    exit 0
fi

INPUT=$(cat)

# --- Session label: env override > cwd + git branch > cwd > session id ---
if [[ -n "$CLAUDE_SESSION_NAME" ]]; then
    LABEL="$CLAUDE_SESSION_NAME"
else
    CWD=$(echo "$INPUT" | grep -o '"cwd":"[^"]*"' | head -1 | cut -d'"' -f4)
    PROJECT="${CWD##*/}"
    BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ -n "$PROJECT" && -n "$BRANCH" ]]; then
        LABEL="$PROJECT ($BRANCH)"
    elif [[ -n "$PROJECT" ]]; then
        LABEL="$PROJECT"
    else
        SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | cut -d'"' -f4)
        LABEL="session ${SESSION_ID:0:6}"
    fi
fi

TITLE="Claude Code"
MESSAGE="$LABEL ready for input"

# --- Pushover push notification ---
curl -s \
  -F "token=$PUSHOVER_TOKEN" \
  -F "user=$PUSHOVER_USER" \
  -F "title=$TITLE" \
  -F "message=$MESSAGE" \
  -F "priority=1" \
  -F "sound=cosmic" \
  https://api.pushover.net/1/messages.json &>/dev/null &

exit 0
