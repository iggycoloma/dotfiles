#!/usr/bin/env bash
# Pre-tool security hook - Block access to sensitive files
#
# Scope is structured file-path arguments: Claude's file tools, Codex's
# apply_patch, and MCP/local tools that expose path/file_path fields. There is
# deliberately no Bash branch. Scanning a command
# string for credential filenames cannot distinguish naming a path from opening
# one, and cannot model quoting or expansion, so it produced steady false
# prompts while missing any non-literal access. On hosts that job belongs to
# `sandbox.credentials` in claude-code/settings.json, which bwrap and Seatbelt
# enforce against every child process; in containers the container boundary
# covers it. See docs/sandbox.md "Why there is no Bash scan".

# Validate jq is available. Security hooks must fail closed: Codex treats
# ordinary hook failures as non-blocking, so emit a deny decision instead of
# exiting non-zero when a dependency is missing.
if ! command -v jq &> /dev/null; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"jq is required for the sensitive-path guard"}}'
    exit 0
fi

# Slurp the whole stdin payload. read -r would stop at the first newline,
# silently dropping pretty-printed JSON into the jq parser and failing open.
input=$(cat)

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
    # The agent CLIs' own OAuth tokens. `*/credentials.json` does not reach
    # these: the leading dot means the char before the match is not a `/`.
    "*/.credentials.json"
    "*/credentials.yaml"
    "*/credentials.yml"
    "*/secrets.yaml"
    "*/secrets.yml"
    "*/secrets.json"
    "*/client_secret*.json"
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
    ".config/glab-cli"
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
    ".copilot"
    ".cursor"
    ".windsurf"
    ".continue"
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

case "$TOOL_NAME" in
    Read|Write|Edit|MultiEdit|NotebookEdit)
        FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')
        check_file_path "$FILE_PATH" && exit 0
        ;;
    mcp__*|read_file|write_file|edit_file)
        while IFS= read -r FILE_PATH; do
            [[ -n "$FILE_PATH" ]] || continue
            check_file_path "$FILE_PATH" && exit 0
        done < <(echo "$input" | jq -r '
            [.tool_input.file_path?, .tool_input.path?, .tool_input.paths[]?]
            | .[] | select(type == "string")')
        ;;
esac

exit 0
