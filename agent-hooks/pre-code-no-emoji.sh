#!/usr/bin/env bash
# Pre-tool emoji validation hook - Prevent agents from adding decorative emojis
# Blocks emojis in new code/docs while allowing markdown task symbols

# Source shared detection patterns
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/shared-patterns.sh"

# Validate jq is available. Content guardrails should fail closed: Codex
# treats ordinary hook failures as non-blocking, so emit a deny decision.
if ! command -v jq &> /dev/null; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"jq is required for the no-emoji guard"}}'
    exit 0
fi

# Slurp the whole stdin payload; read -r stops at the first newline and would
# silently drop multi-line JSON.
input=$(cat)

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
CONTENT_TO_CHECK=""

# Exempt agent-internal write surfaces. Plan-mode output and auto-memory
# entries are agent-generated scratch content, not code or docs we ship,
# so the no-emoji guardrail does not apply. Without this, a stray glyph in
# a generated plan blocks every subsequent plan update with a hard deny.
# Anchor to $HOME so a path-substring match (e.g. /tmp/.claude/plans/x.sh)
# cannot be used by an adversarial prompt to slip non-policy content past
# the check.
FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')
case "$FILE_PATH" in
    "$HOME"/.claude/plans/*|"$HOME"/.claude/projects/*/memory/*|"$HOME"/.codex/plans/*|"$HOME"/.codex/projects/*/memory/*) exit 0 ;;
esac

# Validate file-editing tools.
if [[ "$TOOL_NAME" == "Write" ]]; then
    # For Write: check the entire content being written
    # Known limitation: Write replaces the entire file, so if the existing file
    # already contains emoji, the agent gets blocked from touching it even if it
    # didn't add the emoji. The Edit path (which only checks new_string) is
    # not affected.
    CONTENT_TO_CHECK=$(echo "$input" | jq -r '.tool_input.content // empty')
elif [[ "$TOOL_NAME" == "Edit" ]]; then
    # For Edit: only check new_string (what the agent is adding), not old_string (existing code)
    CONTENT_TO_CHECK=$(echo "$input" | jq -r '.tool_input.new_string // empty')
elif [[ "$TOOL_NAME" == "MultiEdit" ]]; then
    # For MultiEdit: only check new_string values across all edits.
    CONTENT_TO_CHECK=$(echo "$input" | jq -r '[.tool_input.edits[]?.new_string // empty] | join("\n")')
elif [[ "$TOOL_NAME" == "apply_patch" ]]; then
    # Codex apply_patch supplies a patch body. Check added content lines only,
    # not context or removed lines.
    PATCH=$(echo "$input" | jq -r '.tool_input.command // .tool_input.patch // empty')
    CONTENT_TO_CHECK=$(printf '%s\n' "$PATCH" | awk '/^\+/ && $0 !~ /^\+\+\+/ {print substr($0, 2)}')
else
    # Not a tool we care about
    exit 0
fi

# If no content to check, allow
if [[ -z "$CONTENT_TO_CHECK" ]]; then
    exit 0
fi

# Strip allowed task symbols, then check for decorative emojis (uses shared patterns)
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

# All validation passed
exit 0
