#!/usr/bin/env bash
# Tests for claude-code/hooks/pre-code-no-emoji.sh
# Covers:
#   1. Decorative emoji detection in Write tool content
#   2. Decorative emoji detection in Edit tool new_string
#   3. Allowed markdown task symbols pass through
#   4. Non-Write/Edit tools are ignored
#
# Note: emoji test strings are built with printf to avoid triggering
# the pre-code-no-emoji hook on this test file itself.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$DOTFILES_DIR/claude-code/hooks/pre-code-no-emoji.sh"

source "$SCRIPT_DIR/test-framework.sh"

# Build emoji strings via printf so this file stays emoji-free
ROCKET=$(printf '\xF0\x9F\x9A\x80')       # U+1F680
PARTY=$(printf '\xF0\x9F\x8E\x89')        # U+1F389
SPARKLES=$(printf '\xE2\x9C\xA8')         # U+2728
BUG=$(printf '\xF0\x9F\x90\x9B')          # U+1F41B
WARNING=$(printf '\xE2\x9A\xA0\xEF\xB8\x8F') # U+26A0 + U+FE0F

# Helper: simulate a Write tool call, return "denied" or "allowed"
run_write_hook() {
    local content="$1"
    local file_path="${2:-/tmp/test.sh}"
    local json
    json=$(jq -n -c --arg content "$content" --arg fp "$file_path" '{"tool_name":"Write","tool_input":{"file_path":$fp,"content":$content}}')
    local result
    result=$(echo "$json" | bash "$HOOK" 2>/dev/null)
    if [[ -z "$result" ]]; then
        echo "allowed"
    elif echo "$result" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null | grep -q "deny"; then
        echo "denied"
    else
        echo "allowed"
    fi
}

# Helper: simulate an Edit tool call, return "denied" or "allowed"
run_edit_hook() {
    local old_string="$1"
    local new_string="$2"
    local file_path="${3:-/tmp/test.sh}"
    local json
    json=$(jq -n -c --arg old "$old_string" --arg new "$new_string" --arg fp "$file_path" '{"tool_name":"Edit","tool_input":{"file_path":$fp,"old_string":$old,"new_string":$new}}')
    local result
    result=$(echo "$json" | bash "$HOOK" 2>/dev/null)
    if [[ -z "$result" ]]; then
        echo "allowed"
    elif echo "$result" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null | grep -q "deny"; then
        echo "denied"
    else
        echo "allowed"
    fi
}

assert_denied() {
    local result="$1" label="$2"
    if [[ "$result" == "denied" ]]; then
        test_pass "$label"
    else
        test_fail "$label (expected denied, got $result)"
    fi
}

assert_allowed() {
    local result="$1" label="$2"
    if [[ "$result" == "allowed" ]]; then
        test_pass "$label"
    else
        test_fail "$label (expected allowed, got $result)"
    fi
}

#
# Test Suite: Write tool -- decorative emojis blocked
#

test_suite "Write Tool -- Decorative Emojis Blocked"

assert_denied "$(run_write_hook "echo Hello World ${ROCKET}")" \
    "Blocks rocket emoji in Write content"

assert_denied "$(run_write_hook "# ${PARTY} New Feature")" \
    "Blocks party emoji in Write content"

assert_denied "$(run_write_hook "log(${SPARKLES} Success)")" \
    "Blocks sparkles emoji in Write content"

assert_denied "$(run_write_hook "# TODO: fix this ${BUG}")" \
    "Blocks bug emoji in Write content"

assert_denied "$(run_write_hook "${WARNING} Warning message")" \
    "Blocks warning emoji in Write content"

#
# Test Suite: Write tool -- plain text allowed
#

test_suite "Write Tool -- Plain Text Allowed"

assert_allowed "$(run_write_hook 'echo "Hello World"')" \
    "Allows plain text"

assert_allowed "$(run_write_hook '#!/usr/bin/env bash
set -e
echo "done"')" \
    "Allows normal shell script"

assert_allowed "$(run_write_hook 'function test_fn() { return 0; }')" \
    "Allows function definitions"

assert_allowed "$(run_write_hook '')" \
    "Allows empty content"

#
# Test Suite: Write tool -- markdown task symbols allowed
#

test_suite "Write Tool -- Markdown Task Symbols Allowed"

# These use actual UTF-8 symbols that the hook should allow
CHECKMARK=$(printf '\xE2\x9C\x93')   # U+2713
XMARK=$(printf '\xE2\x9C\x97')       # U+2717
HEAVYCHECK=$(printf '\xE2\x9C\x94')  # U+2714
BALLOTX=$(printf '\xE2\x9C\x98')     # U+2718

assert_allowed "$(run_write_hook "- ${CHECKMARK} task completed")" \
    "Allows checkmark symbol"

assert_allowed "$(run_write_hook "- ${XMARK} task failed")" \
    "Allows X mark symbol"

assert_allowed "$(run_write_hook "${HEAVYCHECK} Done ${BALLOTX} Not done")" \
    "Allows heavy check and ballot X"

#
# Test Suite: Edit tool -- only new_string checked
#

test_suite "Edit Tool -- Only new_string Checked"

assert_denied "$(run_edit_hook 'old code' "new code ${ROCKET}")" \
    "Blocks emoji in new_string"

assert_allowed "$(run_edit_hook "old code ${ROCKET}" 'new code without emoji')" \
    "Allows emoji in old_string (existing code)"

assert_allowed "$(run_edit_hook 'old code' 'new code')" \
    "Allows plain text edit"

#
# Test Suite: Claude-internal paths exempt from emoji check
#
# Plan-mode output and auto-memory entries are Claude-generated scratch
# content; emojis there should not block the write. Code/docs paths that
# only happen to live under ~/.claude/ (commands, agents, hooks) still get
# checked.
#

test_suite "Claude-Internal Paths Exempt"

assert_allowed "$(run_write_hook "Step 1 ${ROCKET} ship it" "/home/vscode/.claude/plans/my-plan.md")" \
    "Allows emoji in plan file (Write)"

assert_allowed "$(run_edit_hook "old" "new ${PARTY}" "/home/vscode/.claude/plans/my-plan.md")" \
    "Allows emoji in plan file (Edit)"

assert_allowed "$(run_write_hook "memory note ${SPARKLES}" "/home/vscode/.claude/projects/-some-proj/memory/note.md")" \
    "Allows emoji in auto-memory file (Write)"

assert_allowed "$(run_edit_hook "old" "new ${BUG}" "/home/vscode/.claude/projects/-some-proj/memory/MEMORY.md")" \
    "Allows emoji in auto-memory file (Edit)"

assert_denied "$(run_write_hook "command help ${ROCKET}" "/home/vscode/.claude/commands/foo.md")" \
    "Still blocks emoji under ~/.claude/commands/"

assert_denied "$(run_write_hook "agent description ${PARTY}" "/home/vscode/.claude/agents/foo.md")" \
    "Still blocks emoji under ~/.claude/agents/"

assert_denied "$(run_write_hook "CLAUDE.md note ${SPARKLES}" "/home/vscode/.claude/CLAUDE.md")" \
    "Still blocks emoji in ~/.claude/CLAUDE.md"

#
# Test Suite: Non-Write/Edit tools pass through
#

test_suite "Non-Write/Edit Tools Pass Through"

result=$(echo '{"tool_name":"Bash","tool_input":{"command":"echo test"}}' | bash "$HOOK" 2>/dev/null)
if [[ -z "$result" ]]; then
    test_pass "Bash tool passes through"
else
    test_fail "Bash tool should not be checked"
fi

result=$(echo '{"tool_name":"Read","tool_input":{"file_path":"/tmp/test"}}' | bash "$HOOK" 2>/dev/null)
if [[ -z "$result" ]]; then
    test_pass "Read tool passes through"
else
    test_fail "Read tool should not be checked"
fi

result=$(echo '{"tool_name":"Glob","tool_input":{"pattern":"*.sh"}}' | bash "$HOOK" 2>/dev/null)
if [[ -z "$result" ]]; then
    test_pass "Glob tool passes through"
else
    test_fail "Glob tool should not be checked"
fi

#
# Results
#

echo ""
print_test_summary
