#!/usr/bin/env bash
# Tests for agent-hooks/pre-security.sh
#
# The hook guards file-path arguments only: Claude's Read/Write/Edit/MultiEdit
# and Codex's apply_patch. Bash commands are deliberately not inspected -- see
# the "Bash is not inspected" suite below and docs/sandbox.md
# "Why there is no Bash scan".

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
    payload=$'{\n  "tool_name": "Read",\n  "tool_input": {"file_path": "/home/user/project/.env"}\n}'
    local result
    result=$(printf '%s' "$payload" | bash "$HOOK" 2>/dev/null)
    if [[ -n "$result" ]] && echo "$result" | jq -e '.hookSpecificOutput.permissionDecision' >/dev/null 2>&1; then
        test_pass "Hook blocks pretty-printed JSON payloads"
    else
        test_fail "Hook should not fail open on multi-line JSON"
    fi
}

#
# Bash is not inspected -- deliberate, not a regression.
#
# A substring scan over a command string cannot tell naming a path from opening
# one, and cannot model quoting or expansion. It produced steady false prompts
# (measured: 19 of 60 ordinary dev commands) while missing any non-literal
# access. Credential reads from Bash are now blocked by `sandbox.credentials` in
# claude-code/settings.json, enforced by bwrap/Seatbelt against every child
# process, and by the container boundary in devcontainers.
#
# These assertions exist so re-adding a Bash branch is a deliberate act with a
# failing test attached, not a quiet drift back.
#

test_bash_former_false_positives_pass() {
    assert_allowed "$(run_bash_hook "jq -r '.key' package.json")" "Bash: jq '.key' not inspected"
    assert_allowed "$(run_bash_hook 'cat .env.example')" "Bash: .env.example not inspected"
    # shellcheck disable=SC2016  # literal, passed to the hook verbatim
    assert_allowed "$(run_bash_hook 'export PATH="$HOME/.cargo/bin:$PATH"')" "Bash: .cargo on PATH not inspected"
    assert_allowed "$(run_bash_hook 'rg "settings.local.json" docs/')" "Bash: grepping for a filename not inspected"
    # shellcheck disable=SC2016
    assert_allowed "$(run_bash_hook 'GITHUB_TOKEN=$T gh pr list')" "Bash: scoped env assignment not inspected"
    assert_allowed "$(run_bash_hook 'cat .git/config')" "Bash: .git/config not inspected"
}

test_bash_credential_reads_delegated() {
    # These ARE credential access. The hook no longer blocks them; the sandbox
    # does. Asserting pass-through here keeps the delegation explicit rather
    # than leaving a silent hole nobody documented.
    assert_allowed "$(run_bash_hook 'cat ~/.ssh/id_rsa')" "Bash: ssh key read delegated to sandbox.credentials"
    assert_allowed "$(run_bash_hook 'cat ~/.aws/credentials')" "Bash: aws creds read delegated to sandbox.credentials"
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

test_file_tool_agent_oauth_tokens() {
    assert_blocked "$(run_file_hook Read '/home/user/.claude/.credentials.json')" "Read blocks the Claude OAuth token file"
    assert_blocked "$(run_file_hook Read '/home/user/.codex/.credentials.json')" "Read blocks the Codex OAuth token file"
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
    assert_allowed "$(run_file_hook Read '/home/user/project/package.json')" "Allows package.json"
    assert_allowed "$(run_file_hook Read '/home/user/project/docs/keys.md')" "Allows docs/keys.md"
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

test_structured_mcp_paths() {
    local json result
    json='{"tool_name":"mcp__filesystem__read_file","tool_input":{"path":"/home/user/.ssh/config"}}'
    result=$(echo "$json" | bash "$HOOK" 2>/dev/null)
    if echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "ask" or .hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
        test_pass "Structured MCP path blocks a sensitive read"
    else
        test_fail "Structured MCP path should block a sensitive read"
    fi

    json='{"tool_name":"mcp__filesystem__read_file","tool_input":{"path":"/home/user/project/README.md"}}'
    result=$(echo "$json" | bash "$HOOK" 2>/dev/null)
    if [[ -z "$result" ]]; then
        test_pass "Structured MCP path allows a safe read"
    else
        test_fail "Structured MCP path should allow a safe read"
    fi
}

test_non_bash_tool_passthrough() {
    # Tools other than Read/Write/Edit/apply_patch should pass through
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

    test_suite "Bash is not inspected"
    test_bash_former_false_positives_pass
    test_bash_credential_reads_delegated

    test_suite "File Tool Checks (Read/Write/Edit)"
    test_file_tool_env
    test_file_tool_sensitive_dirs
    test_file_tool_agent_oauth_tokens
    test_file_tool_extensions
    test_file_tool_path_traversal
    test_file_tool_safe_paths

    test_suite "Codex apply_patch Checks"
    test_apply_patch_sensitive_paths
    test_apply_patch_safe_paths

    test_suite "Structured MCP Path Checks"
    test_structured_mcp_paths

    test_suite "Pass-through"
    test_non_bash_tool_passthrough

    print_test_summary
}

main
