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

# Sensitive path patterns (glob-style, anchored with */)
SENSITIVE_PATHS=(
    "*/.env"
    "*/.env.local"
    "*/.env.production"
    "*/.env.staging"
    "*/credentials.json"
    "*/.credentials"
    "*/secrets.yaml"
    "*/secrets.json"
    "*/.aws/credentials"
    "*/.ssh/id_rsa"
    "*/.ssh/id_ed25519"
    "*/.git/config"
)

# Sensitive extension patterns
SENSITIVE_EXTENSIONS=(
    "*.pem"
    "*.key"
    "*.p12"
    "*.pfx"
)

# --- Bash tool: scan command for sensitive path references ---
if [[ "$TOOL_NAME" == "Bash" ]]; then
    COMMAND=$(echo "$input" | jq -r '.tool_input.command // empty')
    [[ -z "$COMMAND" ]] && exit 0

    for pattern in "${SENSITIVE_PATHS[@]}" "${SENSITIVE_EXTENSIONS[@]}"; do
        # Extract the filename/suffix from the glob pattern (strip leading */)
        suffix="${pattern#\*/}"
        if [[ "$COMMAND" == *"$suffix"* ]]; then
            jq -n -c --arg reason "This command may access sensitive file matching: $suffix" \
                '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
            exit 0
        fi
    done
    exit 0
fi

# --- File tools: check file_path directly ---
if [[ "$TOOL_NAME" != "Read" && "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
    exit 0
fi

FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Check if file path matches sensitive path patterns (glob match, not substring)
for pattern in "${SENSITIVE_PATHS[@]}"; do
    if [[ "$FILE_PATH" == $pattern ]]; then
        jq -n -c --arg reason "This file may contain sensitive information: $FILE_PATH" \
            '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
        exit 0
    fi
done

# Check sensitive extensions
for pattern in "${SENSITIVE_EXTENSIONS[@]}"; do
    if [[ "$FILE_PATH" == $pattern ]]; then
        jq -n -c --arg reason "This file may contain sensitive information: $FILE_PATH" \
            '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
        exit 0
    fi
done

# Check for path traversal attempts
# Match ".." as a path component (at start/middle/end of path)
if [[ "$FILE_PATH" =~ (^|/)\.\.($|/) ]]; then
    jq -n -c --arg reason "Path traversal detected in: $FILE_PATH" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
    exit 0
fi

# Allow by default
exit 0
