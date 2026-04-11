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
    "*/.git-credentials"
    "*/config/git/credentials"
    "*/.pgpass"
    "*/.my.cnf"
    "*/.mongorc.js"
)

# Sensitive extension patterns
SENSITIVE_EXTENSIONS=(
    "*.pem"
    "*.key"
    "*.p12"
    "*.pfx"
    "*.ppk"
    "*.tfvars"
    "*.jks"
    "*.keystore"
)

# Sensitive directories - any reference to these dirs (including globs) should prompt
SENSITIVE_DIRS=(
    ".ssh"
    ".aws"
    ".gnupg"
    ".azure"
    ".config/gcloud"
    ".config/gh"
    ".config/hub"
    ".docker"
    ".kube"
    ".config/heroku"
    ".config/doctl"
    ".gradle"
    ".m2"
    ".minikube"
    ".cargo"
    ".gem"
    ".composer"
    ".stripe"
    ".dotfiles-state"
)

# Additional sensitive files not covered by SENSITIVE_PATHS above
SENSITIVE_FILES=(
    ".npmrc"
    ".pypirc"
    ".netrc"
    ".htpasswd"
    ".git/config"
    ".env.vault"
    "settings.local.json"
)

# Glob-adjacent patterns near sensitive files - catches .en*, .env?, etc.
# NOTE: use [*] and [?] instead of \* and \? for perl character class matching
SENSITIVE_GLOB_PATTERNS=(
    '\.en[v*?]'
    '\.env\b'
    '\.htpasswd'
)

# --- Bash tool: scan command for sensitive path references ---
if [[ "$TOOL_NAME" == "Bash" ]]; then
    COMMAND=$(echo "$input" | jq -r '.tool_input.command // empty')
    [[ -z "$COMMAND" ]] && exit 0

    # Check 1: Exact sensitive file substrings (existing check)
    for pattern in "${SENSITIVE_PATHS[@]}" "${SENSITIVE_EXTENSIONS[@]}"; do
        # Extract the filename/suffix from the glob pattern (strip leading */ and *)
        suffix="${pattern#\*/}"
        suffix="${suffix#\*}"
        if [[ "$COMMAND" == *"$suffix"* ]]; then
            jq -n -c --arg reason "This command may access sensitive file matching: $suffix" \
                '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
            exit 0
        fi
    done

    # Check 2: Sensitive directory access (catches globs like ~/.ssh/*, rg ~/.aws/)
    for dir in "${SENSITIVE_DIRS[@]}"; do
        # Match dir followed by /, space, or end-of-string
        if [[ "$COMMAND" == *"$dir/"* ]] || [[ "$COMMAND" == *"$dir "* ]] || [[ "$COMMAND" == *"$dir" ]]; then
            jq -n -c --arg reason "This command may access sensitive directory: $dir" \
                '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
            exit 0
        fi
    done

    # Check 2b: Sensitive standalone files (not in SENSITIVE_PATHS)
    for sensitive_file in "${SENSITIVE_FILES[@]}"; do
        if [[ "$COMMAND" == *"$sensitive_file"* ]]; then
            jq -n -c --arg reason "This command may access sensitive file: $sensitive_file" \
                '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
            exit 0
        fi
    done

    # Check 3: Glob/fuzzy patterns near sensitive files (catches .en*, .env?, etc.)
    # NOTE: perl -ne requires BEGIN/END flag pattern because exit inside -ne loop
    # doesn't prevent END block from running (see memory: perl emoji detection)
    for pattern in "${SENSITIVE_GLOB_PATTERNS[@]}"; do
        if echo "$COMMAND" | perl -ne "BEGIN{\$f=1} if(/$pattern/){\$f=0} END{exit \$f}" 2>/dev/null; then
            jq -n -c --arg reason "This command may access sensitive files (pattern: $pattern)" \
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
    # shellcheck disable=SC2053  # intentional glob matching
    if [[ "$FILE_PATH" == $pattern ]]; then
        jq -n -c --arg reason "This file may contain sensitive information: $FILE_PATH" \
            '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
        exit 0
    fi
done

# Check sensitive extensions
for pattern in "${SENSITIVE_EXTENSIONS[@]}"; do
    # shellcheck disable=SC2053  # intentional glob matching
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
