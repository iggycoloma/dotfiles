#!/usr/bin/env bash
# Tests for unattended/scripts/ralph.sh and ralph-parallel.sh
# Tests syntax, help output, argument parsing, and template substitution

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RALPH_SCRIPT="$DOTFILES_DIR/unattended/scripts/ralph.sh"
PARALLEL_SCRIPT="$DOTFILES_DIR/unattended/scripts/ralph-parallel.sh"

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
assert_contains "$help_output" "--spec-file" "--help mentions --spec-file"
assert_contains "$help_output" "--session-budget" "--help mentions --session-budget"
assert_contains "$help_output" "--run-log-dir" "--help mentions --run-log-dir"

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

# Stricter: UUID-ish format and minimum length.
if [[ "$sid" =~ ^[a-zA-Z0-9-]+$ ]]; then
    test_pass "Session ID matches [a-zA-Z0-9-]+"
else
    test_fail "Session ID matches [a-zA-Z0-9-]+ (got: $sid)"
fi
if [[ ${#sid} -ge 8 ]]; then
    test_pass "Session ID is at least 8 chars"
else
    test_fail "Session ID is at least 8 chars (got length ${#sid})"
fi

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

# Cross-file distinctness regression guard (macOS md5 vs md5sum).
file_a=$(mktemp); printf 'alpha\n' > "$file_a"
file_b=$(mktemp); printf 'bravo\n' > "$file_b"
PROGRESS_FILE="$file_a"; ha=$(progress_hash)
PROGRESS_FILE="$file_b"; hb=$(progress_hash)
assert_not_equals "$ha" "$hb" "progress_hash distinguishes two different files"
assert_not_equals "" "$ha" "progress_hash non-empty for file A"
assert_not_equals "" "$hb" "progress_hash non-empty for file B"
rm -f "$file_a" "$file_b"

# Fallback: stat-based fingerprint also distinguishes two files. We test the
# stat commands directly rather than trying to hide md5sum from `command -v`,
# which is brittle across shells. The cascade in progress_hash uses the same
# stat invocations below.
fallback_a=$(mktemp); printf 'fa\n' > "$fallback_a"
fallback_b=$(mktemp); printf 'fbbb\n' > "$fallback_b"
if stat -c '%Y-%s' "$fallback_a" &>/dev/null; then
    sa=$(stat -c '%Y-%s' "$fallback_a")
    sb=$(stat -c '%Y-%s' "$fallback_b")
    assert_not_equals "$sa" "$sb" "GNU stat fingerprint distinguishes two files"
elif stat -f '%m-%z' "$fallback_a" &>/dev/null; then
    sa=$(stat -f '%m-%z' "$fallback_a")
    sb=$(stat -f '%m-%z' "$fallback_b")
    assert_not_equals "$sa" "$sb" "BSD stat fingerprint distinguishes two files"
else
    test_pass "No stat flavor available; skipping fingerprint distinctness check"
fi
rm -f "$fallback_a" "$fallback_b"

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

# --- Creds file permission gate ---

test_suite "ralph.sh: creds_file_secure"

secure_creds=$(mktemp); chmod 600 "$secure_creds"
creds_file_secure "$secure_creds"
assert_return_code 0 $? "creds_file_secure accepts 0600"

lax_creds=$(mktemp); chmod 644 "$lax_creds"
creds_file_secure "$lax_creds"
rc=$?
assert_not_equals 0 "$rc" "creds_file_secure rejects 0644 (group/other readable)"

chmod 666 "$lax_creds"
creds_file_secure "$lax_creds"
rc=$?
assert_not_equals 0 "$rc" "creds_file_secure rejects 0666"

rm -f "$secure_creds" "$lax_creds"

# --- CLAUDE_UNATTENDED safety gate ---

test_suite "ralph.sh: CLAUDE_UNATTENDED rejects implicit acceptEdits"

unattended_temp=$(mktemp)
echo "prompt body" > "$unattended_temp"
unattended_out=$(mktemp)
CLAUDE_UNATTENDED=1 "$RALPH_SCRIPT" --prompt-file "$unattended_temp" --permission-mode acceptEdits >"$unattended_out" 2>&1
rc=$?
output=$(<"$unattended_out")
# Without the claude CLI, ralph.sh bails at its dependency check before the
# safety gate runs -- the non-zero exit would pass for the wrong reason. Skip
# rather than assert a false green (same pattern as the gh guard in
# tests/test-gh-repo-policy.sh).
if command -v claude &>/dev/null; then
    assert_not_equals 0 "$rc" "CLAUDE_UNATTENDED=1 + acceptEdits without --yolo exits non-zero"
    assert_contains "$output" "requires --yolo" "Error message mentions --yolo requirement"
else
    test_info "Skipping CLAUDE_UNATTENDED gate assertions (claude CLI not installed)"
fi
rm -f "$unattended_temp" "$unattended_out"

# --- Spec helper ---

test_suite "ralph-spec.sh: YAML frontmatter parsing"

# Use a subshell so the sourced functions don't leak further.
(
    source "$DOTFILES_DIR/unattended/scripts/ralph-spec.sh"
    set +e

    spec=$(mktemp)
    # shellcheck disable=SC2119  # cat here does not need $@
    cat >"$spec" <<'SPECEOF'
---
spec_version: 1
tasks:
  - id: alpha
    description: first
    verify: "echo A"
    done: false
  - id: bravo
    description: second
    verify: "echo B"
    done: false
  - id: charlie
    description: third
    verify: "echo C"
    done: false
---
body text
SPECEOF

    # has_tasks
    if spec_has_tasks "$spec"; then
        test_pass "spec_has_tasks detects tasks block"
    else
        test_fail "spec_has_tasks detects tasks block"
    fi

    # next task
    next=$(spec_next_task_id "$spec")
    assert_equals "alpha" "$next" "spec_next_task_id returns first undone task"

    # verify lookup
    v=$(spec_task_verify "$spec" alpha)
    assert_equals "echo A" "$v" "spec_task_verify returns the task's verify string"

    # mark done
    spec_mark_done "$spec" alpha
    next2=$(spec_next_task_id "$spec")
    assert_equals "bravo" "$next2" "spec_mark_done flips done and advances next"

    # idempotent
    spec_mark_done "$spec" alpha
    next3=$(spec_next_task_id "$spec")
    assert_equals "bravo" "$next3" "spec_mark_done is idempotent"

    # all-done false until every task flipped
    assert_equals "false" "$(spec_all_done "$spec")" "spec_all_done false while tasks remain"
    spec_mark_done "$spec" bravo
    spec_mark_done "$spec" charlie
    assert_equals "true" "$(spec_all_done "$spec")" "spec_all_done true when every task done"
    empty_next=$(spec_next_task_id "$spec")
    assert_equals "" "$empty_next" "spec_next_task_id empty when all done"

    # sha
    sha=$(spec_sha "$spec")
    assert_not_equals "" "$sha" "spec_sha returns a non-empty digest"
    if [[ "$sha" =~ ^[a-f0-9]{64}$ ]]; then
        test_pass "spec_sha matches sha256 shape"
    else
        test_fail "spec_sha matches sha256 shape (got: $sha)"
    fi

    # file without frontmatter returns empty / false
    plain=$(mktemp)
    printf '# Not a spec\n' > "$plain"
    if spec_has_tasks "$plain"; then
        test_fail "spec_has_tasks rejects file without frontmatter"
    else
        test_pass "spec_has_tasks rejects file without frontmatter"
    fi
    assert_equals "" "$(spec_next_task_id "$plain")" "spec_next_task_id empty without frontmatter"

    rm -f "$spec" "$plain"
)

# --- Spec-driven verify override via ralph.sh help + arg validation ---

test_suite "ralph.sh: --spec-file validation"

# Missing file -> error.
output=$("$RALPH_SCRIPT" --prompt-file "$RALPH_SCRIPT" --spec-file /nonexistent/spec.md 2>&1)
rc=$?
assert_not_equals 0 "$rc" "--spec-file with missing path exits non-zero"
assert_contains "$output" "Spec file not found" "Error message for missing spec"

# Present but no tasks -> error.
no_tasks=$(mktemp)
# shellcheck disable=SC2119  # cat here does not need $@
cat >"$no_tasks" <<'NOTASKS'
---
spec_version: 1
notes: no task list here
---
body
NOTASKS
output=$("$RALPH_SCRIPT" --prompt-file "$RALPH_SCRIPT" --spec-file "$no_tasks" 2>&1)
rc=$?
assert_not_equals 0 "$rc" "--spec-file without tasks list exits non-zero"
assert_contains "$output" "no 'tasks:'" "Error message for missing tasks list"
rm -f "$no_tasks"

# --- JSONL writer + cumulative cost + session-budget arg validation ---

test_suite "ralph.sh: session-budget validation"

output=$("$RALPH_SCRIPT" --prompt-file "$RALPH_SCRIPT" --session-budget abc 2>&1)
rc=$?
assert_not_equals 0 "$rc" "--session-budget with non-numeric value exits non-zero"
assert_contains "$output" "non-negative number" "Error message for bad session-budget"

# Test the JSONL writer + cumulative_cost in isolation (no claude binary required).
test_suite "ralph.sh: JSONL run log"

(
    set +e
    # Source ralph.sh to get the writer helpers. We disable the main() call
    # by running from a subshell that won't meet the `BASH_SOURCE == $0` check.
    # shellcheck disable=SC1091
    source "$RALPH_SCRIPT" 2>/dev/null
    # Point the log dir at a scratch area.
    RUN_LOG_DIR=$(mktemp -d)
    SESSION_BUDGET="0.50"
    sid="test-$$"

    write_run_log "$sid" 1 0 true "abc123" 10 "deadbeef" "0.10" "1000" "50" "task-x"
    write_run_log "$sid" 2 0 true "def456" 20 "cafebabe" "0.15" "1500" "75" "task-y"

    log_path="$RUN_LOG_DIR/$sid.jsonl"
    if [[ -f "$log_path" ]]; then
        test_pass "JSONL log file created"
    else
        test_fail "JSONL log file created"
    fi

    line_count=$(wc -l < "$log_path" | tr -d ' ')
    assert_equals "2" "$line_count" "JSONL log has one line per iteration"

    # Every line is valid JSON with the required fields.
    required_fields_ok=true
    while IFS= read -r line; do
        for field in session iteration timestamp exit_code verify_passed progress_hash elapsed_s cost_usd task_id; do
            if ! jq -e "has(\"$field\")" <<<"$line" &>/dev/null; then
                required_fields_ok=false
                break 2
            fi
        done
    done < "$log_path"
    if [[ "$required_fields_ok" == true ]]; then
        test_pass "Every JSONL record has the required fields"
    else
        test_fail "Every JSONL record has the required fields"
    fi

    # Cumulative cost sums correctly.
    total=$(cumulative_cost "$sid")
    # jq may print 0.25 or 0.25000... use awk for a tolerant compare.
    if awk -v t="$total" 'BEGIN{ exit (t+0 >= 0.24 && t+0 <= 0.26) ? 0 : 1 }'; then
        test_pass "cumulative_cost sums cost_usd across iterations"
    else
        test_fail "cumulative_cost sums cost_usd across iterations (got: $total)"
    fi

    # Under-budget check.
    if under_session_budget "$sid"; then
        test_pass "under_session_budget true when total < budget"
    else
        test_fail "under_session_budget true when total < budget (total=$total budget=$SESSION_BUDGET)"
    fi

    # Flip past the budget and re-check.
    write_run_log "$sid" 3 0 true "ghi789" 30 "feedface" "0.40" "2000" "100" "task-z"
    if ! under_session_budget "$sid"; then
        test_pass "under_session_budget false when total > budget"
    else
        test_fail "under_session_budget false when total > budget"
    fi

    rm -rf "$RUN_LOG_DIR"
)

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

# --- Counter idiom regression guard ---
# ((var++)) under set -e aborts when var starts at 0 because the post-increment
# expression evaluates to 0 (falsy for (( ))). The parallel runner was bit by
# this; guard the replacement idiom.

test_suite "ralph-parallel.sh: counter idiom under set -e"

counter_result=$(bash -c '
set -euo pipefail
successes=0
successes=$((successes + 1))
successes=$((successes + 1))
echo $successes
' 2>&1)
assert_equals "2" "$counter_result" "successes=\$((successes+1)) increments under set -e"

# Confirm the old idiom would have aborted (sanity check on the diagnosis).
old_idiom_rc=0
bash -c 'set -euo pipefail; successes=0; ((successes++)); echo after=$successes' >/dev/null 2>&1 || old_idiom_rc=$?
assert_not_equals 0 "$old_idiom_rc" "((var++)) under set -e aborts when var starts at 0 (sanity check)"

# Confirm the parallel script no longer uses the bad idiom.
bad_idiom_hits=$(grep -cE '\(\([a-zA-Z_][a-zA-Z0-9_]*\+\+\)\)' "$PARALLEL_SCRIPT" || true)
assert_equals "0" "$bad_idiom_hits" "ralph-parallel.sh has zero ((var++)) occurrences"

# =================================================================
# Templates
# =================================================================

test_suite "Templates"

assert_file_exists "$DOTFILES_DIR/unattended/templates/PROMPT.md" "PROMPT.md template exists"
assert_file_exists "$DOTFILES_DIR/unattended/templates/PRD.md" "PRD.md template exists"
assert_file_exists "$DOTFILES_DIR/unattended/templates/progress.txt" "progress.txt template exists"

assert_file_contains "$DOTFILES_DIR/unattended/templates/PROMPT.md" "{{ITERATION}}" "PROMPT.md has ITERATION placeholder"
assert_file_contains "$DOTFILES_DIR/unattended/templates/PROMPT.md" "{{MAX_ITERATIONS}}" "PROMPT.md has MAX_ITERATIONS placeholder"
assert_file_contains "$DOTFILES_DIR/unattended/templates/PROMPT.md" "{{PROGRESS_FILE}}" "PROMPT.md has PROGRESS_FILE placeholder"
assert_file_contains "$DOTFILES_DIR/unattended/templates/PROMPT.md" "## COMPLETE" "PROMPT.md references COMPLETE signal"
assert_file_contains "$DOTFILES_DIR/unattended/templates/PROMPT.md" "Phase 1" "PROMPT.md has Phase 1 (Orient)"
assert_file_contains "$DOTFILES_DIR/unattended/templates/PROMPT.md" "Phase 4" "PROMPT.md has Phase 4 (Verify)"
assert_file_contains "$DOTFILES_DIR/unattended/templates/progress.txt" "IN_PROGRESS" "progress.txt has initial status"
assert_file_contains "$DOTFILES_DIR/unattended/templates/progress.txt" "Learnings" "progress.txt has Learnings section"

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
# Same reasoning as the CLAUDE_UNATTENDED gate above: without the claude CLI,
# ccw exits early with "claude CLI not found" and never reaches its usage text.
if command -v claude &>/dev/null; then
    assert_not_equals 0 "$rc" "ccw fails without branch arg"
    assert_contains "$output" "Usage" "ccw shows usage without args"
else
    test_info "Skipping ccw usage assertions (claude CLI not installed)"
fi

# --- Summary ---

print_test_summary
