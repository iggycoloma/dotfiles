#!/usr/bin/env bash
# Claude Code statusline - optimized for Claude Max users
# Uses official context_window data instead of hacky transcript estimation
# Features: color-coded context bar, git caching, agent/vim mode support

read -r input

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for statusline" >&2
    exit 1
fi

if ! echo "$input" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON input to statusline" >&2
    exit 1
fi

# Extract fields via individual jq calls (avoids eval injection risk)
MODEL=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
AGENT=$(echo "$input" | jq -r '.agent.name // empty')
VERSION=$(echo "$input" | jq -r '.version // empty')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "~"')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
CONTEXT_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
VIM_MODE=$(echo "$input" | jq -r '.vim.mode // empty')
SESSION_ID=$(echo "$input" | jq -r '.session_id // "default"')

DURATION_MS=${DURATION_MS:-0}
CONTEXT_PCT=${CONTEXT_PCT:-0}
CONTEXT_SIZE=${CONTEXT_SIZE:-200000}

# ANSI color codes (dollar-quoted so escapes work in any context)
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'
DIM=$'\033[2m'
RESET=$'\033[0m'

if [ "$CONTEXT_SIZE" -ge 1000000 ] 2>/dev/null; then
    CONTEXT_SIZE_FMT="1M"
else
    CONTEXT_SIZE_FMT="200K"
fi

CONTEXT_PCT_INT=$(printf "%.0f" "$CONTEXT_PCT" 2>/dev/null || echo 0)
CONTEXT_PCT_INT=${CONTEXT_PCT_INT:-0}

# Green < 70%, Yellow 70-89%, Red >= 90%
if [ "$CONTEXT_PCT_INT" -ge 90 ]; then
    BAR_COLOR="$RED"
elif [ "$CONTEXT_PCT_INT" -ge 70 ]; then
    BAR_COLOR="$YELLOW"
else
    BAR_COLOR="$GREEN"
fi

BAR_WIDTH=10
FILLED=$((CONTEXT_PCT_INT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && BAR=$(printf "%${FILLED}s" | tr ' ' '#')
[ "$EMPTY" -gt 0 ] && BAR="${BAR}$(printf "%${EMPTY}s" | tr ' ' '-')"

DURATION_SEC=$((DURATION_MS / 1000))
if [ "$DURATION_SEC" -lt 60 ]; then
    DURATION="${DURATION_SEC}s"
elif [ "$DURATION_SEC" -lt 3600 ]; then
    MINS=$((DURATION_SEC / 60))
    SECS=$((DURATION_SEC % 60))
    DURATION="${MINS}m${SECS}s"
else
    HOURS=$((DURATION_SEC / 3600))
    MINS=$(((DURATION_SEC % 3600) / 60))
    DURATION="${HOURS}h${MINS}m"
fi

# Git info with 5-second caching (avoids slow git commands on each render)
DIR_NAME="${CWD##*/}"
GIT_CACHE="/tmp/claude-statusline-git-${SESSION_ID}"
CACHE_TIMEOUT=5

cache_is_stale() {
    [ ! -f "$GIT_CACHE" ] || \
    [ $(($(date +%s) - $(stat -c %Y "$GIT_CACHE" 2>/dev/null || stat -f %m "$GIT_CACHE" 2>/dev/null || echo 0))) -gt $CACHE_TIMEOUT ]
}

if cache_is_stale; then
    if git -C "$CWD" rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
        STAGED=$(git -C "$CWD" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(git -C "$CWD" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        echo "${BRANCH}|${STAGED}|${MODIFIED}" > "$GIT_CACHE"
    else
        echo "||" > "$GIT_CACHE"
    fi
fi

IFS='|' read -r BRANCH STAGED MODIFIED < "$GIT_CACHE"

GIT_INFO=""
if [ -n "$BRANCH" ]; then
    GIT_STATUS=""
    [ "${STAGED:-0}" -gt 0 ] && GIT_STATUS="${GREEN}+${STAGED}${RESET}"
    [ "${MODIFIED:-0}" -gt 0 ] && GIT_STATUS="${GIT_STATUS}${YELLOW}~${MODIFIED}${RESET}"
    [ -n "$GIT_STATUS" ] && GIT_STATUS=" ${GIT_STATUS}"
    GIT_INFO=" | ${CYAN}${BRANCH}${RESET}${GIT_STATUS}"
fi

MODEL_STR="$MODEL"
[ -n "$AGENT" ] && MODEL_STR="${MODEL} -> ${AGENT}"

VIM_INDICATOR=""
[ -n "$VIM_MODE" ] && VIM_INDICATOR=" [${VIM_MODE}]"

# Line 1: Model, vim mode, directory, git branch with status
printf '%b\n' "[${MODEL_STR}]${VIM_INDICATOR} ${DIR_NAME}${GIT_INFO}"

# Line 2: Context bar, percentage, duration, version
# Lines changed omitted - Claude Code's built-in status already shows file/line counts
printf '%b\n' "${BAR_COLOR}${BAR}${RESET} ${CONTEXT_PCT_INT}% of ${CONTEXT_SIZE_FMT} | ${DURATION} | ${DIM}v${VERSION}${RESET}"
