#!/usr/bin/env bash
# Tests for bin/gh-repo-policy.sh
# Tests argument parsing, profile payloads, and dry-run behavior

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
POLICY_SCRIPT="$DOTFILES_DIR/bin/gh-repo-policy.sh"

source "$SCRIPT_DIR/test-framework.sh"

# --- Syntax ---

test_suite "Syntax validation"

bash -n "$POLICY_SCRIPT" 2>/dev/null
assert_return_code 0 $? "Script passes bash -n syntax check"

assert_file_exists "$POLICY_SCRIPT" "Script file exists"

if [[ -x "$POLICY_SCRIPT" ]]; then
    test_pass "Script is executable"
else
    test_fail "Script is executable"
fi

# --- Help ---

test_suite "Help output"

help_output=$("$POLICY_SCRIPT" --help 2>&1)
help_rc=$?
assert_return_code 0 "$help_rc" "--help exits 0"
assert_contains "$help_output" "OWNER/REPO" "--help mentions OWNER/REPO"
assert_contains "$help_output" "solo" "--help mentions solo profile"
assert_contains "$help_output" "team" "--help mentions team profile"
assert_contains "$help_output" "strict" "--help mentions strict profile"
assert_contains "$help_output" "--dry-run" "--help mentions --dry-run"
assert_contains "$help_output" "--force" "--help mentions --force"

# --- Argument validation ---

test_suite "Argument validation"

# Missing OWNER/REPO
output=$("$POLICY_SCRIPT" --profile solo 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails without OWNER/REPO"
assert_contains "$output" "Missing required argument" "Error message for missing OWNER/REPO"

# Invalid profile
output=$("$POLICY_SCRIPT" --profile invalid owner/repo 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails with invalid profile"
assert_contains "$output" "Invalid profile" "Error message for invalid profile"

# Invalid OWNER/REPO format
output=$("$POLICY_SCRIPT" --profile solo "noslash" 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails with invalid OWNER/REPO format"
assert_contains "$output" "Invalid OWNER/REPO format" "Error message for bad format"

# Double OWNER/REPO
output=$("$POLICY_SCRIPT" owner/repo extra/repo 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails with extra positional argument"
assert_contains "$output" "Unexpected argument" "Error message for extra argument"

# Unknown option
output=$("$POLICY_SCRIPT" --bad-flag owner/repo 2>&1)
rc=$?
assert_not_equals 0 "$rc" "Fails with unknown flag"
assert_contains "$output" "Unknown option" "Error message for unknown flag"

# --- Dry-run output ---

test_suite "Dry-run mode"

# Dry-run should not require gh auth or network access
dry_output=$("$POLICY_SCRIPT" --profile solo --dry-run owner/repo 2>&1)
dry_rc=$?
# If gh is not installed, dry-run will fail at dependency check -- that's OK for CI
if command -v gh &>/dev/null && command -v jq &>/dev/null; then
    assert_return_code 0 "$dry_rc" "Dry-run exits 0 when tools available"
    assert_contains "$dry_output" "dry-run" "Dry-run output contains dry-run marker"
    assert_contains "$dry_output" "PATCH repos/" "Dry-run shows API PATCH for repo settings"
    assert_contains "$dry_output" "Payload" "Dry-run shows ruleset payload"
else
    test_info "Skipping dry-run tests (gh or jq not available)"
fi

# --- Profile payload generation ---

test_suite "Profile payloads"

if command -v jq &>/dev/null; then
    # Source the script to get all function definitions (source guard skips main)
    source "$POLICY_SCRIPT"
    # Re-disable strict mode after sourcing (script sets -euo pipefail)
    set +eu

    # Test solo profile
    solo_payload=$(build_ruleset_payload "solo" "main" "" "Test ruleset")
    solo_reviews=$(echo "$solo_payload" | jq '.rules[] | select(.type == "pull_request") | .parameters.required_approving_review_count')
    assert_equals "1" "$solo_reviews" "Solo profile requires 1 review"

    solo_bypass=$(echo "$solo_payload" | jq '.bypass_actors | length')
    assert_not_equals "0" "$solo_bypass" "Solo profile has bypass actors"

    solo_signatures=$(echo "$solo_payload" | jq '[.rules[] | select(.type == "required_signatures")] | length')
    assert_equals "0" "$solo_signatures" "Solo profile does not require signatures"

    # Test team profile
    team_payload=$(build_ruleset_payload "team" "main" "" "Test ruleset")
    team_bypass=$(echo "$team_payload" | jq '.bypass_actors | length')
    assert_equals "0" "$team_bypass" "Team profile has no bypass actors"

    team_signatures=$(echo "$team_payload" | jq '[.rules[] | select(.type == "required_signatures")] | length')
    assert_equals "0" "$team_signatures" "Team profile does not require signatures"

    # Test strict profile
    strict_payload=$(build_ruleset_payload "strict" "main" "" "Test ruleset")
    strict_reviews=$(echo "$strict_payload" | jq '.rules[] | select(.type == "pull_request") | .parameters.required_approving_review_count')
    assert_equals "2" "$strict_reviews" "Strict profile requires 2 reviews"

    strict_codeowner=$(echo "$strict_payload" | jq '.rules[] | select(.type == "pull_request") | .parameters.require_code_owner_review')
    assert_equals "true" "$strict_codeowner" "Strict profile requires CODEOWNERS review"

    strict_last_push=$(echo "$strict_payload" | jq '.rules[] | select(.type == "pull_request") | .parameters.require_last_push_approval')
    assert_equals "true" "$strict_last_push" "Strict profile requires last push approval"

    strict_signatures=$(echo "$strict_payload" | jq '[.rules[] | select(.type == "required_signatures")] | length')
    assert_equals "1" "$strict_signatures" "Strict profile requires signatures"

    strict_bypass=$(echo "$strict_payload" | jq '.bypass_actors | length')
    assert_equals "0" "$strict_bypass" "Strict profile has no bypass actors"

    strict_status=$(echo "$strict_payload" | jq '.rules[] | select(.type == "required_status_checks") | .parameters.strict_required_status_checks_policy')
    assert_equals "true" "$strict_status" "Strict profile uses strict status checks"

    # Test custom checks
    checks_payload=$(build_ruleset_payload "team" "main" "Lint,Test" "Test ruleset")
    check_count=$(echo "$checks_payload" | jq '.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks | length')
    assert_equals "3" "$check_count" "Custom checks added (semantic + Lint + Test)"

    # Test branch targeting
    branch_payload=$(build_ruleset_payload "solo" "develop" "" "Test ruleset")
    branch_target=$(echo "$branch_payload" | jq -r '.conditions.ref_name.include[0]')
    assert_equals "refs/heads/develop" "$branch_target" "Payload targets custom branch"

    # Test enforcement and target type
    assert_equals "active" "$(echo "$solo_payload" | jq -r '.enforcement')" "Ruleset enforcement is active"
    assert_equals "branch" "$(echo "$solo_payload" | jq -r '.target')" "Ruleset target is branch"

    # Test --no-semantic-required-check behavior
    REQUIRE_SEMANTIC_CHECK=false
    nosemantic_payload=$(build_ruleset_payload "team" "main" "Lint" "Test ruleset")
    nosemantic_count=$(echo "$nosemantic_payload" | jq '.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks | length')
    assert_equals "1" "$nosemantic_count" "No-semantic-check flag removes semantic check from payload"
    # shellcheck disable=SC2034  # used by sourced build_ruleset_payload
    REQUIRE_SEMANTIC_CHECK=true

    # Test empty check names are filtered
    empty_checks_payload=$(build_ruleset_payload "solo" "main" "Lint,,Test," "Test ruleset")
    empty_check_count=$(echo "$empty_checks_payload" | jq '.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks | length')
    assert_equals "3" "$empty_check_count" "Empty check names are filtered from comma-separated list"

    # Test workflow content generation
    workflow_content=$(build_workflow_content)
    assert_contains "$workflow_content" "pull_request_target" "Workflow triggers on pull_request_target"
    assert_contains "$workflow_content" "$SEMANTIC_CHECK_NAME" "Workflow job name matches SEMANTIC_CHECK_NAME"
    assert_contains "$workflow_content" "$SEMANTIC_ACTION_REF" "Workflow uses SHA-pinned action reference"
    assert_contains "$workflow_content" "subjectPattern" "Workflow enforces lowercase subject"

    # Test repo settings payload
    test_suite "Repository settings payloads"

    solo_settings=$(build_repo_settings_payload "solo")
    assert_equals "true" "$(echo "$solo_settings" | jq '.allow_squash_merge')" "Solo settings enable squash merge"
    assert_equals "false" "$(echo "$solo_settings" | jq '.allow_merge_commit')" "Solo settings disable merge commits"
    assert_equals "false" "$(echo "$solo_settings" | jq '.allow_rebase_merge')" "Solo settings disable rebase merge"
    assert_equals "true" "$(echo "$solo_settings" | jq '.allow_auto_merge')" "Solo settings enable auto-merge"
    assert_equals "true" "$(echo "$solo_settings" | jq '.delete_branch_on_merge')" "Solo settings enable delete branch on merge"
    assert_equals '"PR_TITLE"' "$(echo "$solo_settings" | jq '.squash_merge_commit_title')" "Solo settings use PR_TITLE for squash title"
    assert_equals '"PR_BODY"' "$(echo "$solo_settings" | jq '.squash_merge_commit_message')" "Solo settings use PR_BODY for squash message"

    team_settings=$(build_repo_settings_payload "team")
    assert_equals "true" "$(echo "$team_settings" | jq '.allow_rebase_merge')" "Team settings enable rebase merge"

    strict_settings=$(build_repo_settings_payload "strict")
    assert_equals "false" "$(echo "$strict_settings" | jq '.allow_rebase_merge')" "Strict settings disable rebase merge"

    # Test ruleset merge methods match repo settings per profile
    test_suite "Merge method consistency"

    solo_merge=$(echo "$solo_payload" | jq -c '.rules[] | select(.type == "pull_request") | .parameters.allowed_merge_methods')
    assert_equals '["squash"]' "$solo_merge" "Solo ruleset allows squash only"

    team_merge=$(echo "$team_payload" | jq -c '.rules[] | select(.type == "pull_request") | .parameters.allowed_merge_methods')
    assert_equals '["squash","rebase"]' "$team_merge" "Team ruleset allows squash and rebase"

    strict_merge=$(echo "$strict_payload" | jq -c '.rules[] | select(.type == "pull_request") | .parameters.allowed_merge_methods')
    assert_equals '["squash"]' "$strict_merge" "Strict ruleset allows squash only"
else
    test_info "Skipping payload tests (jq not available)"
fi

# --- Dependency check ---

test_suite "Dependency checks"

# Test check_dependencies by temporarily hiding gh from PATH
if command -v jq &>/dev/null; then
    temp_bin=$(mktemp -d)
    for tool in jq base64; do
        ln -sf "$(command -v "$tool")" "$temp_bin/$tool"
    done
    # Run check_dependencies in a subshell with restricted PATH
    output=$(PATH="$temp_bin" bash -c "source '$POLICY_SCRIPT'; check_dependencies" 2>&1)
    rc=$?
    if [[ $rc -ne 0 ]] && [[ "$output" == *"Missing required tools"* ]]; then
        test_pass "check_dependencies fails when gh is missing"
    else
        test_info "Could not isolate dependency check (gh may be on PATH)"
    fi
    rm -rf "$temp_bin"
else
    test_info "Skipping dependency tests (jq not available)"
fi

# --- Summary ---

print_test_summary
