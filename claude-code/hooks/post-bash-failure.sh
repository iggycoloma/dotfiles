#!/usr/bin/env bash
# PostToolUseFailure hook -- log failed Bash tool calls.
#
# Complements post-dep-audit.sh, which only sees commands that succeed. A log
# of failing commands gives unattended runs a paper trail (repeated failures,
# thrashing) that the transcript buries.
#
# Log: ~/.local/state/claude-code/bash-failures.log
# Observability only: PostToolUseFailure cannot block, and this always exits 0.

command -v jq &>/dev/null || exit 0

input=$(cat)

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
[[ "$TOOL_NAME" != "Bash" ]] && exit 0

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0
LOG_FILE="$LOG_DIR/bash-failures.log"

# Truncate both fields: commands and errors can be arbitrarily large, and the
# log is a scan surface, not a transcript.
echo "$input" | jq -r --arg ts "$(date -Is)" '
    [$ts,
     (.cwd // "?"),
     ((.tool_input.command // "") | gsub("\\s+"; " ") | .[0:300]),
     ((.error // "" | tostring) | gsub("\\s+"; " ") | .[0:500])]
    | join("  |  ")
' >> "$LOG_FILE" 2>/dev/null

exit 0
