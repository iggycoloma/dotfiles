#!/usr/bin/env bash
# Pre-tool emoji validation hook - Prevent Claude from adding decorative emojis
# Blocks emojis in new code/docs while allowing markdown task symbols

# Validate jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
CONTENT_TO_CHECK=""

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

# Markdown task symbols to EXCLUDE from emoji detection (these are allowed)
ALLOWED_SYMBOLS='☐☑✓✗□■▪▫✔✘'

# Remove allowed symbols before checking for emojis
FILTERED_CONTENT=$(echo "$CONTENT_TO_CHECK" | sed "s/[$ALLOWED_SYMBOLS]//g")

# Check for decorative emojis using perl for portability (grep -P unavailable on macOS)
# -CSD enables UTF-8 on stdin/stdout/default encoding
# Covers: Emoticons, Symbols, Pictographs, Transport, Flags, etc.
# Excludes the allowed markdown task symbols filtered above
if echo "$FILTERED_CONTENT" | perl -CSD -ne 'BEGIN{$f=1} if(/[\x{1F000}-\x{1FAFF}\x{2300}-\x{23FF}\x{2600}-\x{27BF}\x{2B50}\x{2B55}\x{FE00}-\x{FE0F}\x{200D}]/){$f=0} END{exit $f}'; then
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
