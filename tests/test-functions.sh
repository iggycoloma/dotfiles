#!/usr/bin/env bash
# Test script to validate shell functions

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
FAILED=0
PASSED=0

# Ensure ~/.local/bin is in PATH (where we install tools)
export PATH="$HOME/.local/bin:$PATH"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
# shellcheck disable=SC2034  # used for future test output
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++)) || true
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++)) || true
}

log_info() {
    echo -e "${BLUE}==>${NC} $1"
}

log_section() {
    echo -e "\n${BLUE}==== $1 ====${NC}\n"
}

# Source the functions to test
source "${DOTFILES_DIR}/shell/functions.sh"

# Helper function to detect ANSI escape codes
has_ansi_codes() {
    local text="$1"
    # Check for ANSI escape sequences
    if echo "$text" | grep -q $'\033\['; then
        return 0
    else
        return 1
    fi
}

# Helper to check for line numbers (bat decorations)
has_line_numbers() {
    local text="$1"
    # Check for bat-style line numbers at start of line (spaces followed by digit(s) followed by tab/spaces)
    if echo "$text" | grep -qE '^\s+[0-9]+\s'; then
        return 0
    else
        return 1
    fi
}

# Create test file for testing
TEST_FILE=$(mktemp)
TEST_OUTPUT=$(mktemp)
echo "Hello World" > "$TEST_FILE"
echo "Line 2" >> "$TEST_FILE"
echo "Line 3" >> "$TEST_FILE"

# Cleanup function
# shellcheck disable=SC2329  # invoked indirectly via trap on EXIT
cleanup() {
    rm -f "$TEST_FILE" "$TEST_OUTPUT"
}
trap cleanup EXIT

log_section "Shell Functions - cat()"

# Test 1: cat with piped output should not have decorations
log_info "Test 1: Piped output should use plain cat (no decorations)"
# shellcheck disable=SC2002  # intentional: testing piped cat behavior
PIPED_OUTPUT=$(cat "$TEST_FILE" | cat)
if has_ansi_codes "$PIPED_OUTPUT"; then
    log_fail "Piped cat output has ANSI codes (should be plain text)"
elif has_line_numbers "$PIPED_OUTPUT"; then
    log_fail "Piped cat output has line numbers (should be plain text)"
else
    log_pass "Piped cat output is plain text (no decorations)"
fi

# Test 2: cat with redirected output should not have decorations
log_info "Test 2: Redirected output should use plain cat (no decorations)"
cat "$TEST_FILE" > "$TEST_OUTPUT"
REDIRECT_OUTPUT=$(command cat "$TEST_OUTPUT")
if has_ansi_codes "$REDIRECT_OUTPUT"; then
    log_fail "Redirected cat output has ANSI codes (should be plain text)"
elif has_line_numbers "$REDIRECT_OUTPUT"; then
    log_fail "Redirected cat output has line numbers (should be plain text)"
else
    log_pass "Redirected cat output is plain text (no decorations)"
fi

# Test 3: command cat should always use plain cat (ccat fallback)
log_info "Test 3: command cat should always use plain cat"
COMMAND_CAT_OUTPUT=$(command cat "$TEST_FILE")
if has_ansi_codes "$COMMAND_CAT_OUTPUT"; then
    log_fail "command cat output has ANSI codes (should be plain text)"
elif has_line_numbers "$COMMAND_CAT_OUTPUT"; then
    log_fail "command cat output has line numbers (should be plain text)"
else
    log_pass "command cat uses plain system cat"
fi

# Test 4: cat function handles multiple files
log_info "Test 4: cat function handles multiple files"
TEST_FILE2=$(mktemp)
echo "File 2" > "$TEST_FILE2"
MULTI_OUTPUT=$(cat "$TEST_FILE" "$TEST_FILE2" | command cat)
if echo "$MULTI_OUTPUT" | grep -q "Hello World" && echo "$MULTI_OUTPUT" | grep -q "File 2"; then
    log_pass "cat function handles multiple files"
else
    log_fail "cat function does not handle multiple files correctly"
fi
rm -f "$TEST_FILE2"

# Test 5: cat function handles nonexistent files gracefully
log_info "Test 5: cat function handles nonexistent files"
if cat /nonexistent/file/path 2>/dev/null; then
    log_fail "cat function should fail for nonexistent files"
else
    log_pass "cat function handles nonexistent files correctly"
fi

# Test 6: Verify cat function exists and is a function
log_info "Test 6: cat is defined as a function"
if declare -f cat &>/dev/null; then
    log_pass "cat is defined as a function"
else
    log_fail "cat is not defined as a function"
fi

# Test 7: Test command substitution (heredoc pattern - the PR description bug)
log_info "Test 7: Command substitution should produce plain text"
HEREDOC_OUTPUT=$(cat <<'EOF'
Line 1
Line 2
EOF
)
if has_ansi_codes "$HEREDOC_OUTPUT"; then
    log_fail "Command substitution output has ANSI codes (should be plain text)"
elif has_line_numbers "$HEREDOC_OUTPUT"; then
    log_fail "Command substitution output has line numbers (should be plain text)"
elif echo "$HEREDOC_OUTPUT" | grep -q "STDIN"; then
    log_fail "Command substitution output has 'STDIN' header (should be plain text)"
else
    log_pass "Command substitution produces plain text (PR description bug fixed)"
fi

# Summary
log_section "Test Summary"
TOTAL=$((PASSED + FAILED))
echo "Total tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

if [[ $FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All function tests passed! ✓${NC}\n"
    exit 0
else
    echo -e "\n${RED}Some function tests failed. Please review the output above.${NC}\n"
    exit 1
fi
