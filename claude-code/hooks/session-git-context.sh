#!/usr/bin/env bash
# Session start hook - Inject git context automatically
# Provides Claude with recent project activity and current state

# Validate jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

read -r input

CWD=$(echo "$input" | jq -r '.cwd // empty')

# Check if we're in a git repository
if ! git -C "$CWD" rev-parse --git-dir &> /dev/null; then
    exit 0
fi

# Gather git context
BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
RECENT_COMMITS=$(git -C "$CWD" log --oneline -5 2>/dev/null)
GIT_STATUS=$(git -C "$CWD" status --short 2>/dev/null)
REMOTE_URL=$(git -C "$CWD" remote get-url origin 2>/dev/null)

# Build context message
CONTEXT_MESSAGE="📍 **Git Context for this session:**

**Current Branch:** \`${BRANCH:-unknown}\`
"

if [[ -n "$REMOTE_URL" ]]; then
    CONTEXT_MESSAGE+="**Remote:** \`${REMOTE_URL}\`
"
fi

if [[ -n "$GIT_STATUS" ]]; then
    UNCOMMITTED_COUNT=$(echo "$GIT_STATUS" | wc -l)
    CONTEXT_MESSAGE+="**Working Directory:** ${UNCOMMITTED_COUNT} uncommitted changes
"
fi

if [[ -n "$RECENT_COMMITS" ]]; then
    CONTEXT_MESSAGE+="
**Recent Commits:**
\`\`\`
${RECENT_COMMITS}
\`\`\`
"
fi

# Return context as system message
echo "{
  \"systemMessage\": $(echo "$CONTEXT_MESSAGE" | jq -Rs .)
}" | jq -c

exit 0
