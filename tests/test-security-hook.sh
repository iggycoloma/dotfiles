#!/usr/bin/env bash
# Tests for agent-hooks/pre-security.sh
# Covers all 4 defense layers:
#   1. Permissions deny list (settings.json) -- not testable here, declarative config
#   2. Exact path/extension substring matching (Check 1)
#   3. Directory-level and standalone file blocking (Check 2, 2b)
#   4. Glob/regex pattern matching (Check 3)

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$DOTFILES_DIR/agent-hooks/pre-security.sh"

source "$SCRIPT_DIR/test-framework.sh"

# Helper: send a Bash command through the hook, return "blocked" or "allowed"
run_bash_hook() {
    local cmd="$1"
    local json
    json=$(jq -n -c --arg cmd "$cmd" '{"tool_name":"Bash","tool_input":{"command":$cmd}}')
    local result
    result=$(echo "$json" | bash "$HOOK" 2>/dev/null)
    if [[ -n "$result" ]]; then
        echo "blocked"
    else
        echo "allowed"
    fi
}

# Helper: send a file tool through the hook, return "blocked", "denied", or "allowed"
run_file_hook() {
    local tool="$1"
    local path="$2"
    local json
    json=$(jq -n -c --arg tool "$tool" --arg path "$path" '{"tool_name":$tool,"tool_input":{"file_path":$path}}')
    local result
    result=$(echo "$json" | bash "$HOOK" 2>/dev/null)
    if [[ -z "$result" ]]; then
        echo "allowed"
    elif echo "$result" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null | grep -q "deny"; then
        echo "denied"
    else
        echo "blocked"
    fi
}

run_apply_patch_hook() {
    local patch="$1"
    local json
    json=$(jq -n -c --arg patch "$patch" '{"tool_name":"apply_patch","tool_input":{"command":$patch}}')
    local result
    result=$(echo "$json" | bash "$HOOK" 2>/dev/null)
    if [[ -z "$result" ]]; then
        echo "allowed"
    elif echo "$result" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null | grep -q "deny"; then
        echo "denied"
    else
        echo "blocked"
    fi
}

assert_blocked() {
    local actual="$1"
    local message="$2"
    if [[ "$actual" == "blocked" ]] || [[ "$actual" == "denied" ]]; then
        test_pass "$message"
    else
        test_fail "$message (expected blocked, got $actual)"
    fi
}

assert_allowed() {
    local actual="$1"
    local message="$2"
    if [[ "$actual" == "allowed" ]]; then
        test_pass "$message"
    else
        test_fail "$message (expected allowed, got $actual)"
    fi
}

#
# Prerequisite: hook syntax valid
#

test_hook_syntax() {
    if bash -n "$HOOK"; then
        test_pass "Hook passes bash -n syntax check"
    else
        test_fail "Hook has syntax errors -- all other tests will fail"
    fi
}

test_hook_requires_jq() {
    # jq is needed; if missing, hook should fail closed with a deny decision.
    local result
    result=$(echo '{}' | PATH=/nonexistent /usr/bin/bash "$HOOK" 2>&1)
    local rc=$?
    if [[ $rc -eq 0 ]] && echo "$result" | grep -q '"permissionDecision":"deny"'; then
        test_pass "Hook denies when jq is missing"
    else
        test_fail "Hook should deny when jq is unavailable"
    fi
}

test_hook_handles_multiline_json() {
    # Regression: read -r used to truncate the payload at the first newline.
    # Pretty-printed JSON would parse-fail in jq and silently allow.
    local payload
    payload=$'{\n  "tool_name": "Bash",\n  "tool_input": {"command": "cat .env"}\n}'
    local result
    result=$(printf '%s' "$payload" | bash "$HOOK" 2>/dev/null)
    if [[ -n "$result" ]] && echo "$result" | jq -e '.hookSpecificOutput.permissionDecision' >/dev/null 2>&1; then
        test_pass "Hook blocks pretty-printed JSON payloads"
    else
        test_fail "Hook should not fail open on multi-line JSON"
    fi
}

#
# Layer 2: Exact path substring matching (SENSITIVE_PATHS + SENSITIVE_EXTENSIONS)
#

test_bash_env_files() {
    assert_blocked "$(run_bash_hook 'cat .env')" "Blocks .env"
    assert_blocked "$(run_bash_hook 'cat .env.local')" "Blocks .env.local"
    assert_blocked "$(run_bash_hook 'cat .env.production')" "Blocks .env.production"
    assert_blocked "$(run_bash_hook 'cat .env.staging')" "Blocks .env.staging"
}

test_bash_credential_files() {
    assert_blocked "$(run_bash_hook 'cat credentials.json')" "Blocks credentials.json"
    assert_blocked "$(run_bash_hook 'cat .credentials')" "Blocks .credentials"
    assert_blocked "$(run_bash_hook 'cat secrets.yaml')" "Blocks secrets.yaml"
    assert_blocked "$(run_bash_hook 'cat secrets.json')" "Blocks secrets.json"
}

test_bash_ssh_keys() {
    assert_blocked "$(run_bash_hook 'cat ~/.ssh/id_rsa')" "Blocks .ssh/id_rsa"
    assert_blocked "$(run_bash_hook 'cat ~/.ssh/id_ed25519')" "Blocks .ssh/id_ed25519"
}

test_bash_git_credentials() {
    assert_blocked "$(run_bash_hook 'cat ~/.git-credentials')" "Blocks .git-credentials"
    assert_blocked "$(run_bash_hook 'cat ~/.config/git/credentials')" "Blocks config/git/credentials"
    assert_blocked "$(run_bash_hook 'cat ~/.git/config')" "Blocks .git/config"
}

test_bash_database_credentials() {
    assert_blocked "$(run_bash_hook 'cat ~/.pgpass')" "Blocks .pgpass"
    assert_blocked "$(run_bash_hook 'cat ~/.my.cnf')" "Blocks .my.cnf"
    assert_blocked "$(run_bash_hook 'cat ~/.mongorc.js')" "Blocks .mongorc.js"
}

test_bash_extensions() {
    assert_blocked "$(run_bash_hook 'cat server.pem')" "Blocks .pem"
    assert_blocked "$(run_bash_hook 'cat private.key')" "Blocks .key"
    assert_blocked "$(run_bash_hook 'cat cert.p12')" "Blocks .p12"
    assert_blocked "$(run_bash_hook 'cat cert.pfx')" "Blocks .pfx"
    assert_blocked "$(run_bash_hook 'cat server.ppk')" "Blocks .ppk"
    assert_blocked "$(run_bash_hook 'cat terraform.tfvars')" "Blocks .tfvars"
    assert_blocked "$(run_bash_hook 'cat app.jks')" "Blocks .jks"
    assert_blocked "$(run_bash_hook 'cat app.keystore')" "Blocks .keystore"
}

#
# Layer 3a: Directory-level blocking (SENSITIVE_DIRS)
#

test_bash_sensitive_dirs_slash() {
    assert_blocked "$(run_bash_hook 'rg x ~/.ssh/')" "Blocks .ssh/ directory access"
    assert_blocked "$(run_bash_hook 'rg x ~/.aws/')" "Blocks .aws/ directory access"
    assert_blocked "$(run_bash_hook 'rg x ~/.gnupg/')" "Blocks .gnupg/ directory access"
    assert_blocked "$(run_bash_hook 'rg x ~/.azure/')" "Blocks .azure/ directory access"
    assert_blocked "$(run_bash_hook 'rg x ~/.config/gcloud/')" "Blocks .config/gcloud/ directory"
    assert_blocked "$(run_bash_hook 'rg x ~/.config/gh/')" "Blocks .config/gh/ directory"
    assert_blocked "$(run_bash_hook 'rg x ~/.docker/')" "Blocks .docker/ directory"
    assert_blocked "$(run_bash_hook 'rg x ~/.kube/')" "Blocks .kube/ directory"
}

test_bash_sensitive_dirs_new() {
    assert_blocked "$(run_bash_hook 'rg x ~/.config/heroku/')" "Blocks .config/heroku/"
    assert_blocked "$(run_bash_hook 'rg x ~/.config/doctl/')" "Blocks .config/doctl/"
    assert_blocked "$(run_bash_hook 'rg x ~/.gradle/')" "Blocks .gradle/"
    assert_blocked "$(run_bash_hook 'rg x ~/.m2/')" "Blocks .m2/"
    assert_blocked "$(run_bash_hook 'rg x ~/.minikube/')" "Blocks .minikube/"
    assert_blocked "$(run_bash_hook 'rg x ~/.cargo/')" "Blocks .cargo/"
    assert_blocked "$(run_bash_hook 'rg x ~/.gem/')" "Blocks .gem/"
    assert_blocked "$(run_bash_hook 'rg x ~/.composer/')" "Blocks .composer/"
    assert_blocked "$(run_bash_hook 'rg x ~/.stripe/')" "Blocks .stripe/"
    # Agent-tool credential dirs from CLAUDE.md.
    assert_blocked "$(run_bash_hook 'cat ~/.copilot/auth.json')" "Blocks .copilot/"
    assert_blocked "$(run_bash_hook 'cat ~/.cursor/credentials')" "Blocks .cursor/"
    assert_blocked "$(run_bash_hook 'cat ~/.windsurf/config')" "Blocks .windsurf/"
    assert_blocked "$(run_bash_hook 'cat ~/.continue/config.json')" "Blocks .continue/"
}

test_bash_sensitive_dirs_glob_bypass() {
    # These previously bypassed the hook via glob expansion
    assert_blocked "$(run_bash_hook 'cp ~/.ssh/* /tmp/')" "Blocks glob copy from .ssh"
    assert_blocked "$(run_bash_hook 'find ~/.ssh -type f | xargs cat')" "Blocks pipe from .ssh"
}

test_bash_shell_expansion_bypass() {
    # Variable expansion that splits a sensitive identifier across tokens.
    # The literal `.ssh` never appears in the command, so substring scans miss
    # it; Check 4 catches the combination of `~/.` and `$`.
    # shellcheck disable=SC2016  # literals being passed as input
    assert_blocked "$(run_bash_hook 'D=ssh; cat ~/.$D/id_rsa')" "Blocks dotfile + var expansion"
    # shellcheck disable=SC2016
    assert_blocked "$(run_bash_hook 'x=$(printf %s ssh); cat ~/.$x/id_rsa')" "Blocks dotfile + command substitution"
    # shellcheck disable=SC2016
    assert_blocked "$(run_bash_hook 'cat $HOME/.$(echo aws)/credentials')" "Blocks \$HOME dotfile + cmd subst"
    # Backtick form
    # shellcheck disable=SC2016
    assert_blocked "$(run_bash_hook 'cat ~/.`echo ssh`/id_rsa')" "Blocks dotfile + backticks"
}

test_bash_sensitive_env_assignment() {
    # Assigning a credential-redirecting env-var is suspicious whether or not
    # the redirected path is sensitive on disk -- the *purpose* is exfil.
    assert_blocked "$(run_bash_hook 'AWS_SHARED_CREDENTIALS_FILE=/tmp/x aws s3 ls')" "Blocks AWS_SHARED_CREDENTIALS_FILE assignment"
    assert_blocked "$(run_bash_hook 'AWS_CONFIG_FILE=/tmp/c aws sts get-caller-identity')" "Blocks AWS_CONFIG_FILE assignment"
    assert_blocked "$(run_bash_hook 'KUBECONFIG=/tmp/k kubectl get pods')" "Blocks KUBECONFIG assignment"
    assert_blocked "$(run_bash_hook 'GNUPGHOME=/tmp/g gpg --list-keys')" "Blocks GNUPGHOME assignment"
    assert_blocked "$(run_bash_hook 'GOOGLE_APPLICATION_CREDENTIALS=/tmp/g gcloud auth list')" "Blocks GOOGLE_APPLICATION_CREDENTIALS assignment"
    assert_blocked "$(run_bash_hook 'export KUBECONFIG=/tmp/k')" "Blocks export KUBECONFIG=..."
    assert_blocked "$(run_bash_hook 'a=1; b=2; AWS_CONFIG_FILE=/tmp/x aws sts get-caller-identity')" "Blocks AWS_CONFIG_FILE after other assigns"
}

test_bash_sensitive_dirs_end_of_string() {
    # Directory at end of command (no trailing /)
    assert_blocked "$(run_bash_hook 'ls ~/.ssh')" "Blocks .ssh at end of command"
    assert_blocked "$(run_bash_hook 'ls ~/.aws')" "Blocks .aws at end of command"
}

#
# Layer 3b: Standalone sensitive files (SENSITIVE_FILES)
#

test_bash_sensitive_standalone_files() {
    assert_blocked "$(run_bash_hook 'cat ~/.npmrc')" "Blocks .npmrc"
    assert_blocked "$(run_bash_hook 'cat ~/.pypirc')" "Blocks .pypirc"
    assert_blocked "$(run_bash_hook 'cat ~/.netrc')" "Blocks .netrc"
    assert_blocked "$(run_bash_hook 'cat ~/.htpasswd')" "Blocks .htpasswd"
    assert_blocked "$(run_bash_hook 'cat .env.vault')" "Blocks .env.vault"
}

#
# Layer 4: Glob/regex pattern matching (SENSITIVE_GLOB_PATTERNS)
#

test_bash_glob_evasion() {
    assert_blocked "$(run_bash_hook 'cat .en*')" "Blocks .en* glob"
    assert_blocked "$(run_bash_hook 'cat .en?')" "Blocks .en? glob"
    assert_blocked "$(run_bash_hook 'cat .envrc')" "Blocks .envrc (matches .env pattern)"
}

test_bash_keyword_not_false_positive() {
    # Keywords in arguments/titles/search terms should NOT trigger blocks.
    # The actual credential files are covered by other layers (Check 1, 2, 2b).
    assert_allowed "$(run_bash_hook 'gh pr create --title "feat: token refresh"')" "Allows token in PR title"
    assert_allowed "$(run_bash_hook 'git commit -m "fix: credential handler"')" "Allows credential in commit message"
    assert_allowed "$(run_bash_hook 'grep -r "password" src/validators.py')" "Allows password as grep argument"
    assert_allowed "$(run_bash_hook 'rg secret src/config/')" "Allows secret as search term"
    assert_allowed "$(run_bash_hook 'git commit -m "fix auth.json handling"')" "Allows auth.json in commit message"
    assert_allowed "$(run_bash_hook 'curl -H "Authorization: Bearer tok" https://api.example.com')" "Allows auth header in curl"
}

test_bash_credential_files_still_blocked() {
    # Actual credential files are still blocked by Check 1 (exact path matching)
    assert_blocked "$(run_bash_hook 'cat credentials.json')" "Blocks credentials.json (Check 1)"
    assert_blocked "$(run_bash_hook 'cat secrets.yaml')" "Blocks secrets.yaml (Check 1)"
    assert_blocked "$(run_bash_hook 'cat secrets.json')" "Blocks secrets.json (Check 1)"
    assert_blocked "$(run_bash_hook 'cat .credentials')" "Blocks .credentials (Check 1)"
    # auth.json in composer dir blocked by Check 2 (directory-level)
    assert_blocked "$(run_bash_hook 'cat ~/.composer/auth.json')" "Blocks ~/.composer/auth.json (Check 2)"
}

#
# File tool checks (Read/Write/Edit path matching)
#

test_file_tool_env() {
    assert_blocked "$(run_file_hook Read '/home/user/project/.env')" "Read blocks .env"
    assert_blocked "$(run_file_hook Write '/home/user/.env.local')" "Write blocks .env.local"
    assert_blocked "$(run_file_hook Edit '/home/user/.env.production')" "Edit blocks .env.production"
    assert_blocked "$(run_file_hook MultiEdit '/home/user/.env.staging')" "MultiEdit blocks .env.staging"
}

test_file_tool_sensitive_dirs() {
    assert_blocked "$(run_file_hook Read '/home/user/.ssh/config')" "Read blocks .ssh directory contents"
    assert_blocked "$(run_file_hook Write '/home/user/.aws/config')" "Write blocks .aws directory contents"
    assert_blocked "$(run_file_hook Edit '/home/user/.config/gh/hosts.yml')" "Edit blocks .config/gh directory contents"
    assert_blocked "$(run_file_hook MultiEdit '/home/user/.docker/config.json')" "MultiEdit blocks .docker directory contents"
}

test_file_tool_extensions() {
    assert_blocked "$(run_file_hook Read '/home/user/server.pem')" "Read blocks .pem"
    assert_blocked "$(run_file_hook Read '/home/user/private.key')" "Read blocks .key"
    assert_blocked "$(run_file_hook Read '/home/user/cert.p12')" "Read blocks .p12"
    assert_blocked "$(run_file_hook Read '/home/user/cert.pfx')" "Read blocks .pfx"
}

test_file_tool_path_traversal() {
    local result
    result=$(run_file_hook Read '/home/user/project/../../etc/passwd')
    assert_equals "denied" "$result" "Denies path traversal with ../"

    # Path traversal to .ssh is caught by .ssh/id_rsa substring match (ask) before
    # the traversal check (deny) -- either result blocks the access
    result=$(run_file_hook Read '/home/user/../.ssh/id_rsa')
    assert_blocked "$result" "Blocks path traversal to .ssh"
}

test_file_tool_safe_paths() {
    assert_allowed "$(run_file_hook Read '/home/user/project/README.md')" "Allows README.md"
    assert_allowed "$(run_file_hook Read '/home/user/project/src/index.js')" "Allows src/index.js"
    assert_allowed "$(run_file_hook Write '/home/user/project/output.txt')" "Allows writing output.txt"
}

#
# Codex apply_patch checks
#

test_apply_patch_sensitive_paths() {
    local patch
    patch='*** Begin Patch
*** Add File: .env
+TOKEN=x
*** End Patch'
    assert_blocked "$(run_apply_patch_hook "$patch")" "apply_patch blocks sensitive add path"

    patch='*** Begin Patch
*** Update File: src/../secrets.json
+{}
*** End Patch'
    assert_blocked "$(run_apply_patch_hook "$patch")" "apply_patch blocks path traversal"

    patch='*** Begin Patch
*** Add File: .ssh/config
+Host example
*** End Patch'
    assert_blocked "$(run_apply_patch_hook "$patch")" "apply_patch blocks sensitive directory path"
}

test_apply_patch_safe_paths() {
    local patch
    patch='*** Begin Patch
*** Add File: docs/example.md
+hello
*** End Patch'
    assert_allowed "$(run_apply_patch_hook "$patch")" "apply_patch allows safe add path"
}

#
# False positive checks - these MUST be allowed
#

test_no_false_positives() {
    assert_allowed "$(run_bash_hook 'ls -la')" "Allows ls"
    assert_allowed "$(run_bash_hook 'git status')" "Allows git status"
    assert_allowed "$(run_bash_hook 'rg TODO src/')" "Allows rg in src/"
    assert_allowed "$(run_bash_hook 'cat README.md')" "Allows cat README.md"
    assert_allowed "$(run_bash_hook 'cp src/foo.js src/bar.js')" "Allows cp in project"
    assert_allowed "$(run_bash_hook 'fd main src/')" "Allows fd in src/"
    assert_allowed "$(run_bash_hook 'scc .')" "Allows scc"
    assert_allowed "$(run_bash_hook 'git log --oneline')" "Allows git log"
    assert_allowed "$(run_bash_hook 'npm test')" "Allows npm test"
    assert_allowed "$(run_bash_hook 'python3 -c print(1)')" "Allows python3"
    # Check-4 shouldn't trip on legitimate dotfile paths that just happen to
    # appear in the same command as a $-expansion. The literal command text
    # contains a $, but Check-4 fires only when $ or ` *immediately follows*
    # the dotfile dot.
    # shellcheck disable=SC2016  # literals being passed to the hook
    assert_allowed "$(run_bash_hook 'echo $HOME/.local/bin')" "Allows \$HOME/.local"
    # shellcheck disable=SC2016
    assert_allowed "$(run_bash_hook 'for f in ~/.local/share/*; do echo \"\$f\"; done')" "Allows ~/.local glob in for-loop"
    # Check-5 shouldn't trip on innocuous assignments.
    # shellcheck disable=SC2016
    assert_allowed "$(run_bash_hook 'PATH=/usr/local/bin:$PATH ls')" "Allows PATH= assignment"
    assert_allowed "$(run_bash_hook 'DEBUG=1 npm test')" "Allows DEBUG= assignment"
}

test_non_bash_tool_passthrough() {
    # Tools other than Bash/Read/Write/Edit should pass through
    local json='{"tool_name":"Glob","tool_input":{"pattern":"**/*.js"}}'
    local result
    result=$(echo "$json" | bash "$HOOK" 2>/dev/null)
    if [[ -z "$result" ]]; then
        test_pass "Glob tool passes through without blocking"
    else
        test_fail "Glob tool should not be checked by security hook"
    fi
}

#
# Run all tests
#

main() {
    echo -e "${CYAN}Starting Security Hook Tests${NC}\n"

    test_suite "Prerequisites"
    test_hook_syntax
    test_hook_requires_jq
    test_hook_handles_multiline_json

    test_suite "Layer 2: Exact Path Matching"
    test_bash_env_files
    test_bash_credential_files
    test_bash_ssh_keys
    test_bash_git_credentials
    test_bash_database_credentials
    test_bash_extensions

    test_suite "Layer 3a: Directory-Level Blocking"
    test_bash_sensitive_dirs_slash
    test_bash_sensitive_dirs_new
    test_bash_sensitive_dirs_glob_bypass
    test_bash_sensitive_dirs_end_of_string
    test_bash_shell_expansion_bypass
    test_bash_sensitive_env_assignment

    test_suite "Layer 3b: Standalone Sensitive Files"
    test_bash_sensitive_standalone_files

    test_suite "Layer 4: Glob/Regex Pattern Matching"
    test_bash_glob_evasion
    test_bash_keyword_not_false_positive
    test_bash_credential_files_still_blocked

    test_suite "File Tool Checks (Read/Write/Edit)"
    test_file_tool_env
    test_file_tool_sensitive_dirs
    test_file_tool_extensions
    test_file_tool_path_traversal
    test_file_tool_safe_paths

    test_suite "Codex apply_patch Checks"
    test_apply_patch_sensitive_paths
    test_apply_patch_safe_paths

    test_suite "False Positive Prevention"
    test_no_false_positives
    test_non_bash_tool_passthrough

    print_test_summary
}

main
