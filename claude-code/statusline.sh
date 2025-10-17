#!/usr/bin/env bash

read -r input

# Validate jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for statusline" >&2
    exit 1
fi

# Validate input is valid JSON
if ! echo "$input" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON input to statusline" >&2
    exit 1
fi

MODEL=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "~"')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Extract transcript information for token estimation
TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path // empty')
SESSION_ID=$(echo "$input" | jq -r '.session_id // "default"')

# Estimate token count from transcript with 5-second caching
TOKENS_TOTAL=0
CACHE_FILE="/tmp/claude-statusline-tokens-${SESSION_ID}"
CACHE_TIMEOUT=5

if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    # Check if cache exists and is fresh (< 5 seconds old)
    if [[ -f "$CACHE_FILE" ]]; then
        CACHE_AGE=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)))
        if [[ $CACHE_AGE -lt $CACHE_TIMEOUT ]]; then
            # Use cached value
            TOKENS_TOTAL=$(cat "$CACHE_FILE" 2>/dev/null || echo 0)
        else
            # Cache expired, recalculate
            TRANSCRIPT_SIZE=$(du -k "$TRANSCRIPT_PATH" 2>/dev/null | cut -f1)
            TOKENS_TOTAL=$((TRANSCRIPT_SIZE * 250))
            echo "$TOKENS_TOTAL" > "$CACHE_FILE" 2>/dev/null
        fi
    else
        # No cache, calculate and cache
        TRANSCRIPT_SIZE=$(du -k "$TRANSCRIPT_PATH" 2>/dev/null | cut -f1)
        TOKENS_TOTAL=$((TRANSCRIPT_SIZE * 250))
        echo "$TOKENS_TOTAL" > "$CACHE_FILE" 2>/dev/null
    fi
fi

# Format token count (use K for thousands, add ~ to indicate estimate)
if [ "$TOKENS_TOTAL" -ge 1000 ]; then
    TOKENS_DISPLAY="~$((TOKENS_TOTAL / 1000))K"
else
    TOKENS_DISPLAY="~$TOKENS_TOTAL"
fi

# Format duration
DURATION_SEC=$((DURATION_MS / 1000))
if [ "$DURATION_SEC" -lt 60 ]; then
    DURATION="${DURATION_SEC}s"
elif [ "$DURATION_SEC" -lt 3600 ]; then
    MINS=$((DURATION_SEC / 60))
    SECS=$((DURATION_SEC % 60))
    DURATION="${MINS}m ${SECS}s"
else
    HOURS=$((DURATION_SEC / 3600))
    MINS=$(((DURATION_SEC % 3600) / 60))
    DURATION="${HOURS}h ${MINS}m"
fi

DIR_NAME="${CWD##*/}"
GIT_BRANCH=""
if git -C "$CWD" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
    [ -n "$BRANCH" ] && GIT_BRANCH=" | 🌿 $BRANCH"
fi

printf "📁 %s%s | 🤖 %s | ⏱️  %s | 🪙 %s tok | 💰 \$%.4f | +%s/-%s\n" \
    "$DIR_NAME" "$GIT_BRANCH" "$MODEL" "$DURATION" "$TOKENS_DISPLAY" "$COST" "$LINES_ADDED" "$LINES_REMOVED"