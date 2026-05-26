#!/usr/bin/env bash
# Pre-tool security hook - Block access to sensitive files
# Prevents accidental exposure of credentials, keys, and secrets

# Validate jq is available. Security hooks must fail closed: Codex treats
# ordinary hook failures as non-blocking, so emit a deny decision instead of
# exiting non-zero when a dependency is missing.
if ! command -v jq &> /dev/null; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"jq is required for the sensitive-path guard"}}'
    exit 0
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
ASK_DECISION="${DOTFILES_HOOK_ASK_DECISION:-ask}"

emit_decision() {
    local decision="$1"
    local reason="$2"
    jq -n -c --arg decision "$decision" --arg reason "$reason" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $decision, permissionDecisionReason: $reason}}'
}

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

check_file_path() {
    local file_path="$1"
    local pattern relative_pattern sensitive_file dir

    for pattern in "${SENSITIVE_PATHS[@]}"; do
        relative_pattern="${pattern#\*/}"
        # shellcheck disable=SC2053  # intentional glob matching
        if [[ "$file_path" == $pattern ]] || [[ "$file_path" == $relative_pattern ]]; then
            emit_decision "$ASK_DECISION" "This file may contain sensitive information: $file_path"
            return 0
        fi
    done

    for sensitive_file in "${SENSITIVE_FILES[@]}"; do
        if [[ "$file_path" == "$sensitive_file" ]] || [[ "$file_path" == */"$sensitive_file" ]]; then
            emit_decision "$ASK_DECISION" "This file may contain sensitive information: $file_path"
            return 0
        fi
    done

    for dir in "${SENSITIVE_DIRS[@]}"; do
        if [[ "$file_path" == "$dir" ]] || [[ "$file_path" == "$dir/"* ]] ||
            [[ "$file_path" == */"$dir" ]] || [[ "$file_path" == */"$dir/"* ]]; then
            emit_decision "$ASK_DECISION" "This file may be in a sensitive directory: $file_path"
            return 0
        fi
    done

    for pattern in "${SENSITIVE_EXTENSIONS[@]}"; do
        # shellcheck disable=SC2053  # intentional glob matching
        if [[ "$file_path" == $pattern ]]; then
            emit_decision "$ASK_DECISION" "This file may contain sensitive information: $file_path"
            return 0
        fi
    done

    if [[ "$file_path" =~ (^|/)\.\.($|/) ]]; then
        emit_decision "deny" "Path traversal detected in: $file_path"
        return 0
    fi

    return 1
}

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
            emit_decision "$ASK_DECISION" "This command may access sensitive file matching: $suffix"
            exit 0
        fi
    done

    # Check 2: Sensitive directory access (catches globs like ~/.ssh/*, rg ~/.aws/)
    for dir in "${SENSITIVE_DIRS[@]}"; do
        # Match dir followed by /, space, or end-of-string
        if [[ "$COMMAND" == *"$dir/"* ]] || [[ "$COMMAND" == *"$dir "* ]] || [[ "$COMMAND" == *"$dir" ]]; then
            emit_decision "$ASK_DECISION" "This command may access sensitive directory: $dir"
            exit 0
        fi
    done

    # Check 2b: Sensitive standalone files (not in SENSITIVE_PATHS)
    for sensitive_file in "${SENSITIVE_FILES[@]}"; do
        if [[ "$COMMAND" == *"$sensitive_file"* ]]; then
            emit_decision "$ASK_DECISION" "This command may access sensitive file: $sensitive_file"
            exit 0
        fi
    done

    # Check 3: Glob/fuzzy patterns near sensitive files (catches .en*, .env?, etc.)
    # NOTE: perl -ne requires BEGIN/END flag pattern because exit inside -ne loop
    # doesn't prevent END block from running (see memory: perl emoji detection)
    for pattern in "${SENSITIVE_GLOB_PATTERNS[@]}"; do
        if echo "$COMMAND" | perl -ne "BEGIN{\$f=1} if(/$pattern/){\$f=0} END{exit \$f}" 2>/dev/null; then
            emit_decision "$ASK_DECISION" "This command may access sensitive files (pattern: $pattern)"
            exit 0
        fi
    done

    exit 0
fi

# --- Codex apply_patch: inspect patch target paths directly ---
if [[ "$TOOL_NAME" == "apply_patch" ]]; then
    PATCH=$(echo "$input" | jq -r '.tool_input.command // .tool_input.patch // empty')
    [[ -z "$PATCH" ]] && exit 0

    while IFS= read -r line; do
        case "$line" in
            "*** Add File: "*|"*** Update File: "*|"*** Delete File: "*|"*** Move to: "*)
                FILE_PATH="${line#*: }"
                check_file_path "$FILE_PATH" && exit 0
                ;;
        esac
    done <<< "$PATCH"

    exit 0
fi

# --- File tools: check file_path directly ---
if [[ "$TOOL_NAME" != "Read" && "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "MultiEdit" ]]; then
    exit 0
fi

FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')
check_file_path "$FILE_PATH" && exit 0

# Allow by default
exit 0
