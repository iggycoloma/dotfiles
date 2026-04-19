#!/usr/bin/env bash
# Tests for claude-code/scripts/ralph.sh and ralph-parallel.sh
# Tests syntax, help output, argument parsing, and template substitution

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RALPH_SCRIPT="$DOTFILES_DIR/claude-code/scripts/ralph.sh"
PARALLEL_SCRIPT="$DOTFILES_DIR/claude-code/scripts/ralph-parallel.sh"

source "$SCRIPT_DIR/test-framework.sh"

# =================================================================
# ralph.sh
# =================================================================

test_suite "ralph.sh: Syntax validation"

bash -n "$RALPH_SCRIPT" 2>/dev/null
assert_return_code 0 $? "ralph.sh passes bash -n syntax check"
assert_file_exists "$RALPH_SCRIPT" "ralph.sh exists"

if [[ -x "$RALPH_SCRIPT" ]]; then
    test_pass "ralph.sh is executable"
else
    test_fail "ralph.sh is executable"
fi

# --- Help ---

test_suite "ralph.sh: Help output"

help_output=$("$RALPH_SCRIPT" --help 2>&1)
help_rc=$?
assert_return_code 0 "$help_rc" "--help exits 0"
assert_contains "$help_output" "--prompt-file" "--help mentions --prompt-file"
assert_contains "$help_output" "--max-iterations" "--help mentions --max-iterations"
assert_contains "$help_output" "--max-budget-usd" "--help mentions --max-budget-usd"
assert_contains "$help_output" "--permission-mode" "--help mentions --permission-mode"
assert_contains "$help_output" "--worktree" "--help mentions --worktree"
assert_contains "$help_output" "--no-notify" "--help mentions --no-notify"
assert_contains "$help_output" "--bare" "--help mentions --bare"
assert_contains "$help_output" "--verify-cmd" "--help mentions --verify-cmd"
assert_contains "$help_output" "--no-checkpoint" "--help mentions --no-checkpoint"
assert_contains "$help_output" "--circuit-breaker" "--help mentions --circuit-breaker"
assert_contains "$help_output" "--yolo" "--help mentions --yolo"

# --- Argument validation ---

test_suite "ralph.sh: Argument validation"

output=$("$RALPH_SCRIPT" 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails without --prompt-file"
assert_contains "$output" "Missing required" "Error message for missing prompt-file"

output=$("$RALPH_SCRIPT" --prompt-file /nonexistent/file.md 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails with nonexistent prompt file"
assert_contains "$output" "not found" "Error message for nonexistent file"

output=$("$RALPH_SCRIPT" --prompt-file "$RALPH_SCRIPT" --max-iterations abc 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails with non-numeric max-iterations"
assert_contains "$output" "positive integer" "Error message for non-numeric iterations"

output=$("$RALPH_SCRIPT" --bad-flag 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails with unknown flag"
assert_contains "$output" "Unknown option" "Error message for unknown flag"

output=$("$RALPH_SCRIPT" --prompt-file "$RALPH_SCRIPT" --prd /nonexistent/prd.md 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails with nonexistent PRD file"
assert_contains "$output" "PRD file not found" "Error message for missing PRD"

output=$("$RALPH_SCRIPT" --prompt-file "$RALPH_SCRIPT" --circuit-breaker abc 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails with non-numeric circuit-breaker"
assert_contains "$output" "non-negative integer" "Error message for bad circuit-breaker"

# --- Template substitution ---

test_suite "ralph.sh: Template substitution"

# Source the script to get render_prompt
source "$RALPH_SCRIPT"
set +eu  # re-disable strict mode after sourcing

# Create a temp prompt file
temp_dir=$(mktemp -d)
# shellcheck disable=SC2119  # cat here does not need $@
cat > "$temp_dir/test-prompt.md" <<'EOF'
Iteration {{ITERATION}} of {{MAX_ITERATIONS}}. Progress at {{PROGRESS_FILE}}.
EOF

# shellcheck disable=SC2034  # used by sourced render_prompt
PROMPT_FILE="$temp_dir/test-prompt.md"
rendered=$(render_prompt "3" "20" "./progress.txt")
assert_contains "$rendered" "Iteration 3 of 20" "Substitutes ITERATION and MAX_ITERATIONS"
assert_contains "$rendered" "Progress at ./progress.txt" "Substitutes PROGRESS_FILE"
assert_not_contains "$rendered" "{{" "No unsubstituted placeholders remain"

rm -rf "$temp_dir"

# --- Session ID generation ---

test_suite "ralph.sh: Session ID generation"

sid=$(generate_session_id)
assert_not_equals "" "$sid" "Session ID is not empty"

# --- Verification helper ---

test_suite "ralph.sh: Verification gating"

VERIFY_CMD="true"
run_verify >/dev/null 2>&1
assert_return_code 0 $? "run_verify passes when VERIFY_CMD=true"

VERIFY_CMD="false"
run_verify >/dev/null 2>&1
rc=$?
assert_not_equals 0 "$rc" "run_verify fails when VERIFY_CMD=false"

# shellcheck disable=SC2034  # used by sourced run_verify
VERIFY_CMD=""
run_verify >/dev/null 2>&1
assert_return_code 0 $? "run_verify is a no-op when VERIFY_CMD is empty"

# --- Progress hash ---

test_suite "ralph.sh: Circuit breaker helpers"

progress_temp=$(mktemp)
echo "## Status: IN_PROGRESS" > "$progress_temp"
PROGRESS_FILE="$progress_temp"

hash1=$(progress_hash)
assert_not_equals "" "$hash1" "progress_hash returns non-empty for existing file"

hash2=$(progress_hash)
assert_equals "$hash1" "$hash2" "progress_hash is stable for unchanged file"

echo "## Completed Tasks: task-1" >> "$progress_temp"
hash3=$(progress_hash)
assert_not_equals "$hash1" "$hash3" "progress_hash changes when file changes"

PROGRESS_FILE="/nonexistent/file"
hash4=$(progress_hash)
assert_equals "empty" "$hash4" "progress_hash returns 'empty' for missing file"

rm -f "$progress_temp"
# shellcheck disable=SC2034  # used by sourced progress_hash
PROGRESS_FILE="./progress.txt"

# --- Git checkpoint ---

test_suite "ralph.sh: Git checkpoint"

CHECKPOINT=false
git_checkpoint 1 >/dev/null 2>&1
assert_return_code 0 $? "git_checkpoint is a no-op when CHECKPOINT=false"

# shellcheck disable=SC2034  # reset for subsequent tests
CHECKPOINT=true

# =================================================================
# ralph-parallel.sh
# =================================================================

test_suite "ralph-parallel.sh: Syntax validation"

bash -n "$PARALLEL_SCRIPT" 2>/dev/null
assert_return_code 0 $? "ralph-parallel.sh passes bash -n syntax check"
assert_file_exists "$PARALLEL_SCRIPT" "ralph-parallel.sh exists"

if [[ -x "$PARALLEL_SCRIPT" ]]; then
    test_pass "ralph-parallel.sh is executable"
else
    test_fail "ralph-parallel.sh is executable"
fi

# --- Help ---

test_suite "ralph-parallel.sh: Help output"

help_output=$("$PARALLEL_SCRIPT" --help 2>&1)
help_rc=$?
assert_return_code 0 "$help_rc" "--help exits 0"
assert_contains "$help_output" "--prompt-file" "--help mentions --prompt-file"
assert_contains "$help_output" "branch" "--help mentions branch specs"

# --- Argument validation ---

test_suite "ralph-parallel.sh: Argument validation"

output=$("$PARALLEL_SCRIPT" 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails without --prompt-file"

output=$("$PARALLEL_SCRIPT" --prompt-file "$RALPH_SCRIPT" 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails without specs"
assert_contains "$output" "No specs" "Error message for missing specs"

output=$("$PARALLEL_SCRIPT" --prompt-file "$RALPH_SCRIPT" "bad-format" 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails with invalid spec format"
assert_contains "$output" "Invalid spec" "Error message for bad spec format"

# =================================================================
# Templates
# =================================================================

test_suite "Templates"

assert_file_exists "$DOTFILES_DIR/claude-code/templates/PROMPT.md" "PROMPT.md template exists"
assert_file_exists "$DOTFILES_DIR/claude-code/templates/PRD.md" "PRD.md template exists"
assert_file_exists "$DOTFILES_DIR/claude-code/templates/progress.txt" "progress.txt template exists"

assert_file_contains "$DOTFILES_DIR/claude-code/templates/PROMPT.md" "{{ITERATION}}" "PROMPT.md has ITERATION placeholder"
assert_file_contains "$DOTFILES_DIR/claude-code/templates/PROMPT.md" "{{MAX_ITERATIONS}}" "PROMPT.md has MAX_ITERATIONS placeholder"
assert_file_contains "$DOTFILES_DIR/claude-code/templates/PROMPT.md" "{{PROGRESS_FILE}}" "PROMPT.md has PROGRESS_FILE placeholder"
assert_file_contains "$DOTFILES_DIR/claude-code/templates/PROMPT.md" "## COMPLETE" "PROMPT.md references COMPLETE signal"
assert_file_contains "$DOTFILES_DIR/claude-code/templates/PROMPT.md" "Phase 1" "PROMPT.md has Phase 1 (Orient)"
assert_file_contains "$DOTFILES_DIR/claude-code/templates/PROMPT.md" "Phase 4" "PROMPT.md has Phase 4 (Verify)"
assert_file_contains "$DOTFILES_DIR/claude-code/templates/progress.txt" "IN_PROGRESS" "progress.txt has initial status"
assert_file_contains "$DOTFILES_DIR/claude-code/templates/progress.txt" "Learnings" "progress.txt has Learnings section"

# =================================================================
# Shell functions
# =================================================================

test_suite "Worktree shell functions"

# Source functions.sh to check definitions
source "$DOTFILES_DIR/shell/functions.sh" 2>/dev/null
set +eu

declare -f ccw &>/dev/null
assert_return_code 0 $? "ccw function is defined"

declare -f ccwls &>/dev/null
assert_return_code 0 $? "ccwls function is defined"

declare -f ccwclean &>/dev/null
assert_return_code 0 $? "ccwclean function is defined"

# Test ccw without args
# shellcheck disable=SC2119  # testing ccw with no args intentionally
output=$(ccw 2>&1)
rc=$?
assert_not_equals 0 "$rc" "ccw fails without branch arg"
assert_contains "$output" "Usage" "ccw shows usage without args"

# --- Summary ---

print_test_summary
