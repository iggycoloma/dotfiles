#!/usr/bin/env bash
# Pre-tool emoji validation hook - Prevent Claude from adding decorative emojis
# Blocks emojis in new code/docs while allowing markdown task symbols (☐☑✓✗)

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
# ☐ ☑ ✓ ✗ □ ■ ▪ ▫ and similar task/checkbox indicators
ALLOWED_SYMBOLS='☐☑✓✗□■▪▫✔✘'

# Remove allowed symbols before checking for emojis
FILTERED_CONTENT=$(echo "$CONTENT_TO_CHECK" | sed "s/[$ALLOWED_SYMBOLS]//g")

# Check for decorative emojis (comprehensive Unicode emoji ranges)
# Covers: Emoticons, Symbols, Pictographs, Transport, Flags, etc.
# Excludes the allowed markdown task symbols filtered above
if echo "$FILTERED_CONTENT" | grep -qP '[\x{1F300}-\x{1F9FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}\x{1F000}-\x{1F02F}\x{1F0A0}-\x{1F0FF}\x{1F100}-\x{1F64F}\x{1F680}-\x{1F6FF}\x{1F900}-\x{1F9FF}\x{1FA00}-\x{1FA6F}\x{1FA70}-\x{1FAFF}\x{2300}-\x{23FF}\x{2B50}\x{2B55}\x{231A}\x{231B}\x{2328}\x{23CF}\x{23E9}-\x{23FF}\x{24C2}\x{25AA}\x{25AB}\x{25B6}\x{25C0}\x{25FB}-\x{25FE}\x{2618}\x{261D}\x{2620}\x{2622}\x{2623}\x{2626}\x{262A}\x{262E}\x{262F}\x{2638}-\x{263A}\x{2640}\x{2642}\x{2648}-\x{2653}\x{265F}\x{2660}\x{2663}\x{2665}\x{2666}\x{2668}\x{267B}\x{267E}\x{267F}\x{2692}-\x{2697}\x{2699}\x{269B}\x{269C}\x{26A0}\x{26A1}\x{26A7}\x{26AA}\x{26AB}\x{26B0}\x{26B1}\x{26BD}\x{26BE}\x{26C4}\x{26C5}\x{26C8}\x{26CE}\x{26CF}\x{26D1}\x{26D3}\x{26D4}\x{26E9}\x{26EA}\x{26F0}-\x{26F5}\x{26F7}-\x{26FA}\x{26FD}\x{2702}\x{2705}\x{2708}-\x{270D}\x{270F}\x{2712}\x{2714}\x{2716}\x{271D}\x{2721}\x{2728}\x{2733}\x{2734}\x{2744}\x{2747}\x{274C}\x{274E}\x{2753}-\x{2755}\x{2757}\x{2763}\x{2764}\x{2795}-\x{2797}\x{27A1}\x{27B0}\x{27BF}\x{2934}\x{2935}\x{2B05}-\x{2B07}\x{2B1B}\x{2B1C}\x{3030}\x{303D}\x{3297}\x{3299}]'; then
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"Decorative emojis detected in new content.\\n\\nPlease remove decorative emojis from the code/documentation.\\n\\nNote: Markdown task symbols (☐ ☑ ✓ ✗) are allowed.\"
  }
}" | jq -c
    exit 0
fi

# All validation passed
exit 0
