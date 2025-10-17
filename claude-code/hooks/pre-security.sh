#!/usr/bin/env bash
# Pre-tool security hook - Block access to sensitive files
# Prevents accidental exposure of credentials, keys, and secrets

# Validate jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only check file-related tools
if [[ "$TOOL_NAME" != "Read" && "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
    exit 0
fi

# Sensitive file patterns to block
SENSITIVE_PATTERNS=(
    ".env"
    ".env.local"
    ".env.production"
    "credentials.json"
    ".credentials"
    "secrets.yaml"
    "secrets.json"
    ".aws/credentials"
    ".ssh/id_rsa"
    ".ssh/id_ed25519"
    "*.pem"
    "*.key"
    "*.p12"
    "*.pfx"
    ".git/config"
    "token"
    "apikey"
)

# Check if file path matches sensitive patterns
for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    if [[ "$FILE_PATH" == *"$pattern"* ]]; then
        echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"ask\",
    \"permissionDecisionReason\": \"⚠️  This file may contain sensitive information: $FILE_PATH\"
  }
}" | jq -c
        exit 0
    fi
done

# Check for path traversal attempts
# Match ".." as a path component (at start/middle/end of path)
if [[ "$FILE_PATH" =~ (^|/)\.\.($|/) ]]; then
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"🚫 Path traversal detected in: $FILE_PATH\"
  }
}" | jq -c
    exit 0
fi

# Allow by default
exit 0
