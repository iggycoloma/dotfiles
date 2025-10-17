#!/usr/bin/env bash
# User prompt submit hook - Monitor context usage
# Warns when approaching token limits

# Validate jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

read -r input

# Extract context usage information
TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path // empty')

# If we have access to transcript, estimate context usage
if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    # Get transcript size in KB
    TRANSCRIPT_SIZE=$(du -k "$TRANSCRIPT_PATH" 2>/dev/null | cut -f1)

    # Rough estimate: 1KB ≈ 250 tokens (very approximate)
    # This is a heuristic, not exact
    ESTIMATED_TOKENS=$((TRANSCRIPT_SIZE * 250))

    # Context limits (approximate)
    # Sonnet 4.5: 200k tokens
    WARNING_THRESHOLD=150000  # Warn at 75% of 200k
    CRITICAL_THRESHOLD=180000 # Critical at 90% of 200k

    if [[ $ESTIMATED_TOKENS -gt $CRITICAL_THRESHOLD ]]; then
        echo "{
  \"systemMessage\": \"⚠️ **Context Usage Critical**: Estimated ~${ESTIMATED_TOKENS} tokens used. Consider using /clear or summarizing the conversation to avoid context limits.\"
}" | jq -c
    elif [[ $ESTIMATED_TOKENS -gt $WARNING_THRESHOLD ]]; then
        echo "{
  \"systemMessage\": \"💡 **Context Usage High**: Estimated ~${ESTIMATED_TOKENS} tokens used. You may want to consider compacting the conversation soon.\"
}" | jq -c
    fi
fi

exit 0
