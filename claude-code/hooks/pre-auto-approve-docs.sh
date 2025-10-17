#!/usr/bin/env bash
# Pre-tool auto-approve hook - Auto-approve safe documentation reads
# Speeds up workflow by reducing permission prompts for safe files

# Validate jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only auto-approve Read operations
if [[ "$TOOL_NAME" != "Read" ]]; then
    exit 0
fi

# Safe file extensions to auto-approve
SAFE_EXTENSIONS=(
    ".md"
    ".mdx"
    ".txt"
    ".json"
    ".yaml"
    ".yml"
    ".toml"
    ".ini"
    ".cfg"
    ".conf"
    ".xml"
    ".html"
    ".css"
    ".rst"
    ".adoc"
    "README"
    "LICENSE"
    "CHANGELOG"
    "CONTRIBUTING"
)

# Check if file matches safe patterns
for ext in "${SAFE_EXTENSIONS[@]}"; do
    # Exact match: path must end with extension, or basename must equal pattern
    if [[ "$FILE_PATH" == *"$ext" ]] || [[ "$(basename "$FILE_PATH")" == "$ext" ]]; then
        echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"allow\",
    \"permissionDecisionReason\": \"Auto-approved documentation file\"
  },
  \"suppressOutput\": true
}" | jq -c
        exit 0
    fi
done

# Don't block, just pass through for normal permission handling
exit 0
