#!/usr/bin/env bash
# Pre-tool emoji validation hook - Prevent agents from adding decorative emojis
# Blocks emojis in new code/docs while allowing markdown task symbols

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/shared-patterns.sh"

# Fail closed: Codex treats ordinary hook failures as non-blocking, so a
# missing jq must produce an explicit deny rather than a non-zero exit.
if ! command -v jq &> /dev/null; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"jq is required for the no-emoji guard"}}'
    exit 0
fi

# Slurp the whole stdin payload; read -r stops at the first newline and would
# silently drop multi-line JSON.
input=$(cat)

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
CONTENT_TO_CHECK=""

# Plans and auto-memory are agent scratch content, not code we ship, and a
# stray glyph in one would otherwise hard-deny every subsequent update.
# Anchored to $HOME so an adversarial /tmp/.claude/plans/x.sh cannot match.
FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')
case "$FILE_PATH" in
    "$HOME"/.claude/plans/*|"$HOME"/.claude/projects/*/memory/*|"$HOME"/.codex/plans/*|"$HOME"/.codex/projects/*/memory/*) exit 0 ;;
esac

# Every branch inspects only content the agent is adding, so pre-existing
# emoji never blocks an edit. Write is the exception: it replaces the whole
# file, so a stray glyph anywhere in the file blocks the write.
case "$TOOL_NAME" in
    Write)
        CONTENT_TO_CHECK=$(echo "$input" | jq -r '.tool_input.content // empty') ;;
    Edit)
        CONTENT_TO_CHECK=$(echo "$input" | jq -r '.tool_input.new_string // empty') ;;
    MultiEdit)
        CONTENT_TO_CHECK=$(echo "$input" | jq -r '[.tool_input.edits[]?.new_string // empty] | join("\n")') ;;
    apply_patch)
        PATCH=$(echo "$input" | jq -r '.tool_input.command // .tool_input.patch // empty')
        CONTENT_TO_CHECK=$(printf '%s\n' "$PATCH" | awk '/^\+/ && $0 !~ /^\+\+\+/ {print substr($0, 2)}') ;;
    *)
        exit 0 ;;
esac

if [[ -z "$CONTENT_TO_CHECK" ]]; then
    exit 0
fi

FILTERED_CONTENT=$(strip_allowed_symbols "$CONTENT_TO_CHECK")

if has_emoji "$FILTERED_CONTENT"; then
    # shellcheck disable=SC2028  # JSON literal, not escape sequences
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"Decorative emojis detected in new content.\\n\\nPlease remove decorative emojis from the code/documentation.\\n\\nNote: Markdown task symbols are allowed.\"
  }
}" | jq -c
    exit 0
fi

exit 0
