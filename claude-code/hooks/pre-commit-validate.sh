#!/usr/bin/env bash
# Pre-tool commit validation hook - Universal commit message validation
# Ensures commit messages follow best practices (format, no AI attribution, no emojis)

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

# Check for AI tool attribution (uses shared patterns)
if has_ai_attribution "$FULL_MSG"; then
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

# Check for co-authoring tags (uses shared patterns)
if has_coauthor_tag "$FULL_MSG"; then
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

# Check for emojis (uses shared patterns)
if has_emoji "$FULL_MSG"; then
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
