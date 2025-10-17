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

# Try to extract from -m flag (try double quotes first, then single quotes)
if [[ "$COMMAND" =~ -m[[:space:]]+\"([^\"]*)\" ]]; then
    COMMIT_MSG="${BASH_REMATCH[1]}"
    FULL_MSG="$COMMIT_MSG"
elif [[ "$COMMAND" =~ -m[[:space:]]+\'([^\']*)\' ]]; then
    COMMIT_MSG="${BASH_REMATCH[1]}"
    FULL_MSG="$COMMIT_MSG"
elif [[ "$COMMAND" =~ \$\(cat[[:space:]]+\<\<[[:space:]]*[\'\"]*EOF ]]; then
    # Extract from heredoc - get full message for attribution check
    FULL_MSG=$(echo "$COMMAND" | sed -n '/cat.*<<.*EOF/,/EOF/p' | sed '1d;$d')
    COMMIT_MSG=$(echo "$FULL_MSG" | head -1)
fi

# If we couldn't extract a message, allow (might be using -F or editor)
if [[ -z "$COMMIT_MSG" ]]; then
    exit 0
fi

# ============================================================================
# 1. COMMIT MESSAGE VALIDATION
# ============================================================================

# Check for AI tool attribution (case-insensitive)
if echo "$FULL_MSG" | grep -qiE "(claude code|claude\.com|anthropic\.com|generated with|powered by.*claude|gpt-|copilot|ai-generated|ai generated)"; then
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"❌ Commit message contains AI tool attribution.\\n\\nCommit messages should not include:\\n  - Claude Code attribution\\n  - Generated with [Tool] messages\\n  - AI tool references\\n\\nPlease remove AI attribution from the commit message.\"
  }
}" | jq -c
    exit 0
fi

# Check for co-authoring tags
if echo "$FULL_MSG" | grep -qiE "co-authored-by:|co-authored by:"; then
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"❌ Commit message contains co-authoring tags.\\n\\nCommit messages should not include:\\n  - Co-Authored-By: tags\\n  - Co-authored-by: tags\\n\\nPlease remove co-authoring tags from the commit message.\"
  }
}" | jq -c
    exit 0
fi

# Check for emojis (Unicode emoji ranges)
# Covers: Emoticons, Symbols, Pictographs, Transport, Flags, etc.
if echo "$FULL_MSG" | grep -qP '[\x{1F300}-\x{1F9FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}\x{1F000}-\x{1F02F}\x{1F0A0}-\x{1F0FF}\x{1F100}-\x{1F64F}\x{1F680}-\x{1F6FF}\x{1F900}-\x{1F9FF}\x{1FA00}-\x{1FA6F}\x{1FA70}-\x{1FAFF}\x{2300}-\x{23FF}\x{2B50}\x{2B55}\x{231A}\x{231B}\x{2328}\x{23CF}\x{23E9}-\x{23FF}\x{24C2}\x{25AA}\x{25AB}\x{25B6}\x{25C0}\x{25FB}-\x{25FE}\x{2600}-\x{2604}\x{260E}\x{2611}\x{2614}\x{2615}\x{2618}\x{261D}\x{2620}\x{2622}\x{2623}\x{2626}\x{262A}\x{262E}\x{262F}\x{2638}-\x{263A}\x{2640}\x{2642}\x{2648}-\x{2653}\x{265F}\x{2660}\x{2663}\x{2665}\x{2666}\x{2668}\x{267B}\x{267E}\x{267F}\x{2692}-\x{2697}\x{2699}\x{269B}\x{269C}\x{26A0}\x{26A1}\x{26A7}\x{26AA}\x{26AB}\x{26B0}\x{26B1}\x{26BD}\x{26BE}\x{26C4}\x{26C5}\x{26C8}\x{26CE}\x{26CF}\x{26D1}\x{26D3}\x{26D4}\x{26E9}\x{26EA}\x{26F0}-\x{26F5}\x{26F7}-\x{26FA}\x{26FD}\x{2702}\x{2705}\x{2708}-\x{270D}\x{270F}\x{2712}\x{2714}\x{2716}\x{271D}\x{2721}\x{2728}\x{2733}\x{2734}\x{2744}\x{2747}\x{274C}\x{274E}\x{2753}-\x{2755}\x{2757}\x{2763}\x{2764}\x{2795}-\x{2797}\x{27A1}\x{27B0}\x{27BF}\x{2934}\x{2935}\x{2B05}-\x{2B07}\x{2B1B}\x{2B1C}\x{2B50}\x{2B55}\x{3030}\x{303D}\x{3297}\x{3299}]'; then
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"❌ Commit message contains emojis.\\n\\nCommit messages should not include emoji characters.\\n\\nPlease remove emojis from the commit message.\"
  }
}" | jq -c
    exit 0
fi

# Conventional commit types
VALID_TYPES="feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"

# Check for conventional commit format
# Scope must start with letter, description must start with lowercase letter
if [[ ! "$COMMIT_MSG" =~ ^($VALID_TYPES)(\([a-z][a-z0-9-]*\))?:[[:space:]][a-z].+ ]]; then
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"ask\",
    \"permissionDecisionReason\": \"⚠️  Commit message doesn't follow conventional commits format.\\n\\nExpected: <type>[optional scope]: <description>\\n\\nValid types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert\\n\\nExample: 'feat(auth): add user login functionality'\\n\\nCurrent message: ${COMMIT_MSG}\"
  }
}" | jq -c
    exit 0
fi

# Check minimum message length
MSG_LENGTH=${#COMMIT_MSG}
if [[ $MSG_LENGTH -lt 10 ]]; then
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"ask\",
    \"permissionDecisionReason\": \"⚠️  Commit message is too short (${MSG_LENGTH} chars). Please provide a more descriptive message (min 10 chars).\"
  }
}" | jq -c
    exit 0
fi

# All validation passed
exit 0
