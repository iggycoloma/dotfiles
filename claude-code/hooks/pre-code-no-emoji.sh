#!/usr/bin/env bash
# Pre-tool emoji validation hook - Prevent Claude from adding decorative emojis
# Blocks emojis in new code/docs while allowing markdown task symbols

# Source shared detection patterns
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/shared-patterns.sh"

# Validate jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
CONTENT_TO_CHECK=""

# Exempt Claude-internal write surfaces. Plan-mode output and auto-memory
# entries are Claude-generated scratch content, not code or docs we ship,
# so the no-emoji guardrail does not apply. Without this, a stray glyph in
# a generated plan blocks every subsequent plan update with a hard deny.
FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')
case "$FILE_PATH" in
    */.claude/plans/*|*/.claude/projects/*/memory/*) exit 0 ;;
esac

# Only validate Write and Edit tools
if [[ "$TOOL_NAME" == "Write" ]]; then
    # For Write: check the entire content being written
    # Known limitation: Write replaces the entire file, so if the existing file
    # already contains emoji, Claude gets blocked from touching it even if it
    # didn't add the emoji. The Edit path (which only checks new_string) is
    # not affected.
    CONTENT_TO_CHECK=$(echo "$input" | jq -r '.tool_input.content // empty')
elif [[ "$TOOL_NAME" == "Edit" ]]; then
    # For Edit: only check new_string (what Claude is adding), not old_string (existing code)
    CONTENT_TO_CHECK=$(echo "$input" | jq -r '.tool_input.new_string // empty')
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
