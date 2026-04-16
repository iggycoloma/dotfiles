#!/usr/bin/env bash
# PostToolUse hook - log Write/Edit file paths that escape the project scope.
#
# Non-blocking by design: unattended runs are often intentional about editing
# a neighbor directory (shared config, sibling package), and blocking would be
# disruptive. We log every out-of-scope write to ~/.local/state/ralph/scope-audit.log
# so the operator can review what the agent did before merging.
#
# Scope root resolution order:
#   1. $CLAUDE_SCOPE_ROOT (caller-supplied; ralph sets this per worktree)
#   2. $CLAUDE_PROJECT_DIR (Claude Code's project root)
#   3. $PWD (fallback)

if ! command -v jq &>/dev/null; then
    exit 0
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0

SCOPE_ROOT="${CLAUDE_SCOPE_ROOT:-${CLAUDE_PROJECT_DIR:-$PWD}}"

# Resolve both to absolute paths. realpath may not exist in every container,
# so fall back to a pure-bash canonicalization.
canonicalize() {
    local p="$1"
    if command -v realpath &>/dev/null; then
        realpath -m "$p" 2>/dev/null || echo "$p"
    else
        case "$p" in
            /*) echo "$p" ;;
            *)  echo "$PWD/$p" ;;
        esac
    fi
}

ABS_FILE=$(canonicalize "$FILE_PATH")
ABS_SCOPE=$(canonicalize "$SCOPE_ROOT")

# Normalize trailing slash so the prefix check is reliable.
ABS_SCOPE="${ABS_SCOPE%/}"

case "$ABS_FILE" in
    "$ABS_SCOPE"|"$ABS_SCOPE"/*)
        # In scope; nothing to audit.
        exit 0
        ;;
esac

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ralph"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

LOG_FILE="$LOG_DIR/scope-audit.log"
printf '%s  tool=%s  scope=%s  path=%s\n' \
    "$(date -Is)" "$TOOL_NAME" "$ABS_SCOPE" "$ABS_FILE" >> "$LOG_FILE"

# Also surface to stderr so attended sessions see the warning immediately.
printf 'scope-audit: %s wrote to %s (scope=%s)\n' \
    "$TOOL_NAME" "$ABS_FILE" "$ABS_SCOPE" >&2

exit 0
