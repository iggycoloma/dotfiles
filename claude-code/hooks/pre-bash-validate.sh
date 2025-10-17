#!/usr/bin/env bash
# Pre-tool Bash validation hook - Prevent dangerous bash commands
# System prompt already guides Claude away from grep/find, so this focuses on safety

# Validate jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
COMMAND=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only validate Bash tool
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

# Dangerous command patterns: pattern -> action and message
declare -A DANGEROUS_COMMANDS=(
    ["rm -rf /"]="deny:🚨 DANGEROUS: This would delete your entire filesystem!"
    ["rm -rf ~"]="deny:🚨 DANGEROUS: This would delete your home directory!"
    ["rm -rf \$HOME"]="deny:🚨 DANGEROUS: This would delete your home directory!"
    ["mkfs"]="deny:🚨 DANGEROUS: This would format a filesystem!"
    ["dd if=/dev/zero"]="deny:🚨 DANGEROUS: Dangerous dd operation detected!"
    ["dd if=/dev/random"]="deny:🚨 DANGEROUS: Dangerous dd operation detected!"
    ["> /dev/sd"]="deny:🚨 DANGEROUS: Direct disk write operation detected!"
    ["> /dev/nvme"]="deny:🚨 DANGEROUS: Direct disk write operation detected!"
    ["curl.*|.*bash"]="ask:⚠️  Piping remote scripts to bash can be dangerous"
    ["curl.*|.*sh"]="ask:⚠️  Piping remote scripts to shell can be dangerous"
    ["wget.*|.*bash"]="ask:⚠️  Piping remote scripts to bash can be dangerous"
    ["wget.*|.*sh"]="ask:⚠️  Piping remote scripts to shell can be dangerous"
    ["chmod 777"]="ask:⚠️  777 permissions are insecure - consider more restrictive permissions"
    ["chmod -R 777"]="ask:⚠️  Recursive 777 permissions are very insecure"
    ["sudo rm -rf"]="ask:⚠️  Potentially dangerous: Careful with sudo rm -rf"
)

# Check for dangerous patterns
for pattern in "${!DANGEROUS_COMMANDS[@]}"; do
    if [[ "$COMMAND" =~ $pattern ]]; then
        IFS=':' read -r action message <<< "${DANGEROUS_COMMANDS[$pattern]}"

        echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"$action\",
    \"permissionDecisionReason\": \"$message\"
  }
}" | jq -c
        exit 0
    fi
done

# Allow by default
exit 0
