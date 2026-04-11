#!/usr/bin/env bash
# Pre-tool commit validation hook - Universal commit message validation
# Ensures commit messages follow best practices (format, no AI attribution, no emojis)

# Validate jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
COMMAND=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only validate git commit commands
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

# Check if this is a git commit command
if [[ ! "$COMMAND" =~ git[[:space:]]+commit ]]; then
    exit 0
fi

# Extract commit message from the command
# Handle both -m "message" and heredoc formats
COMMIT_MSG=""
FULL_MSG=""

# Check heredoc format FIRST (before -m) because Claude wraps heredocs in
# outer double quotes: git commit -m "$(cat <<'EOF' ... EOF)" which would
# match the -m regex and miss the actual multi-line message
if [[ "$COMMAND" =~ \$\(cat[[:space:]]+\<\<[[:space:]]*[\'\"]*EOF ]]; then
    # Extract from heredoc - get full message for attribution check
    FULL_MSG=$(echo "$COMMAND" | sed -n '/cat.*<<.*EOF/,/EOF/p' | sed '1d;$d')
    COMMIT_MSG=$(echo "$FULL_MSG" | head -1)
elif [[ "$COMMAND" =~ -m[[:space:]]+\"([^\"]*)\" ]]; then
    COMMIT_MSG="${BASH_REMATCH[1]}"
    FULL_MSG="$COMMIT_MSG"
elif [[ "$COMMAND" =~ -m[[:space:]]+\'([^\']*)\' ]]; then
    COMMIT_MSG="${BASH_REMATCH[1]}"
    FULL_MSG="$COMMIT_MSG"
fi

# If we couldn't extract a message, allow (might be using -F or editor)
if [[ -z "$COMMIT_MSG" ]]; then
    exit 0
fi

# ============================================================================
# 1. COMMIT MESSAGE VALIDATION
# ============================================================================

# Check for AI tool attribution (case-insensitive)
# Match attribution phrases, not bare tool names -- file paths like
# ~/.copilot/ or "Claude Code configuration" are technical references,
# not attribution. The pattern requires context words around tool names.
if echo "$FULL_MSG" | grep -qiE "(generated (with|by)|powered by|created (with|by)|written (with|by)|assisted by|produced by|authored by|built with|made with).*(claude|anthropic|gpt|openai|copilot|gemini|cursor|windsurf|ai)" ||
   echo "$FULL_MSG" | grep -qiE "(claude|anthropic|gpt|openai|copilot|gemini|cursor|windsurf|ai).*(generated|powered|created|wrote|assisted|produced|authored|built)" ||
   echo "$FULL_MSG" | grep -qiE "(claude\.com|anthropic\.com|ai-generated|ai generated)"; then
    # shellcheck disable=SC2028  # JSON literal, not escape sequences
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"Commit message contains AI tool attribution.\\n\\nCommit messages should not include:\\n  - Claude Code attribution\\n  - Generated with [Tool] messages\\n  - AI tool references\\n\\nPlease remove AI attribution from the commit message.\"
  }
}" | jq -c
    exit 0
fi

# Check for co-authoring tags
if echo "$FULL_MSG" | grep -qiE "co-authored-by:|co-authored by:"; then
    # shellcheck disable=SC2028  # JSON literal, not escape sequences
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"Commit message contains co-authoring tags.\\n\\nCommit messages should not include:\\n  - Co-Authored-By: tags\\n  - Co-authored-by: tags\\n\\nPlease remove co-authoring tags from the commit message.\"
  }
}" | jq -c
    exit 0
fi

# Check for emojis (Unicode emoji ranges) using perl for portability (grep -P unavailable on macOS)
if echo "$FULL_MSG" | perl -CSD -ne 'BEGIN{$f=1} if(/[\x{1F000}-\x{1FAFF}\x{2300}-\x{23FF}\x{2600}-\x{27BF}\x{2B50}\x{2B55}\x{FE00}-\x{FE0F}\x{200D}]/){$f=0} END{exit $f}'; then
    # shellcheck disable=SC2028  # JSON literal, not escape sequences
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"Commit message contains emojis.\\n\\nCommit messages should not include emoji characters.\\n\\nPlease remove emojis from the commit message.\"
  }
}" | jq -c
    exit 0
fi

# Conventional commit types
VALID_TYPES="feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"

# Check for conventional commit format
# Scope must start with letter, description must start with lowercase letter
if [[ ! "$COMMIT_MSG" =~ ^($VALID_TYPES)(\([a-z][a-z0-9-]*\))?:[[:space:]][a-z].+ ]]; then
    jq -n -c --arg reason "Commit message doesn't follow conventional commits format.\n\nExpected: <type>[optional scope]: <description>\n\nValid types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert\n\nExample: 'feat(auth): add user login functionality'\n\nCurrent message: $COMMIT_MSG" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
    exit 0
fi

# Check minimum message length
MSG_LENGTH=${#COMMIT_MSG}
if [[ $MSG_LENGTH -lt 10 ]]; then
    jq -n -c --arg reason "Commit message is too short ($MSG_LENGTH chars). Please provide a more descriptive message (min 10 chars)." \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
    exit 0
fi

# All validation passed
exit 0
