#!/usr/bin/env bash
# Tests for bin/dc-audit.sh.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DC_AUDIT="$DOTFILES_DIR/bin/dc-audit.sh"
RUBRIC="$DOTFILES_DIR/unattended/devcontainer-rubric.json"
FIXTURES="$SCRIPT_DIR/fixtures/devcontainers"

source "$SCRIPT_DIR/test-framework.sh"

# =================================================================
# Syntax + help
# =================================================================

test_suite "dc-audit: Syntax validation"

bash -n "$DC_AUDIT" 2>/dev/null
assert_return_code 0 $? "dc-audit.sh passes bash -n syntax check"
assert_file_exists "$DC_AUDIT" "dc-audit.sh exists"
if [[ -x "$DC_AUDIT" ]]; then
    test_pass "dc-audit.sh is executable"
else
    test_fail "dc-audit.sh is executable"
fi

assert_file_exists "$RUBRIC" "devcontainer-rubric.json exists"
jq empty "$RUBRIC" 2>/dev/null
assert_return_code 0 $? "devcontainer-rubric.json is valid JSON"

test_suite "dc-audit: Help output"

help_output=$("$DC_AUDIT" --help 2>&1)
assert_return_code 0 $? "--help exits 0"
assert_contains "$help_output" "--profile" "--help mentions --profile"
assert_contains "$help_output" "--fix" "--help mentions --fix"
assert_contains "$help_output" "--strict" "--help mentions --strict"
assert_contains "$help_output" "--json" "--help mentions --json"

# =================================================================
# Argument validation
# =================================================================

test_suite "dc-audit: Argument validation"

output=$("$DC_AUDIT" --profile bogus "$FIXTURES/minimal.json" 2>&1)
rc=$?
assert_not_equals 0 "$rc" "rejects unknown --profile value"

output=$("$DC_AUDIT" --bogus-flag "$FIXTURES/minimal.json" 2>&1)
rc=$?
assert_not_equals 0 "$rc" "rejects unknown option"
assert_contains "$output" "Unknown option" "error message for unknown option"

output=$("$DC_AUDIT" --rubric /nonexistent/rubric.json "$FIXTURES/minimal.json" 2>&1)
rc=$?
assert_not_equals 0 "$rc" "rejects missing --rubric path"

output=$("$DC_AUDIT" --rubric "$RUBRIC" /nonexistent/devcontainer.json 2>&1)
rc=$?
assert_not_equals 0 "$rc" "non-zero when target file missing"

# =================================================================
# Rule evaluation: dirty fixtures
# =================================================================

test_suite "dc-audit: Detects minimal-fixture gaps (attended)"

output=$("$DC_AUDIT" --profile attended --rubric "$RUBRIC" "$FIXTURES/minimal.json" 2>&1)
assert_contains "$output" "shutdown-action" "flags missing shutdownAction"
assert_contains "$output" "no-new-privileges" "flags missing --security-opt=no-new-privileges"
assert_contains "$output" "pids-limit-attended" "flags missing pids-limit"

test_suite "dc-audit: Detects minimal-fixture gaps (unattended)"

output=$("$DC_AUDIT" --profile unattended --rubric "$RUBRIC" "$FIXTURES/minimal.json" 2>&1)
assert_contains "$output" "pids-limit-unattended" "unattended profile flags missing pids-limit"
assert_contains "$output" "memory-cap-unattended" "unattended profile flags missing memory cap"
assert_contains "$output" "cap-drop-unattended" "unattended profile flags missing cap-drop=ALL"

test_suite "dc-audit: Detects missing-image error"

output=$("$DC_AUDIT" --profile attended --rubric "$RUBRIC" "$FIXTURES/no-image.json" 2>&1)
rc=$?
assert_contains "$output" "image-required" "flags missing image field"
assert_not_equals 0 "$rc" "exits non-zero when an error-severity rule fails"

test_suite "dc-audit: Detects forbidden credential mount (unattended)"

output=$("$DC_AUDIT" --profile unattended --rubric "$RUBRIC" "$FIXTURES/unattended-bad-mount.json" 2>&1)
assert_contains "$output" "no-host-creds-unattended" "flags ~/.ssh bind mount"

test_suite "dc-audit: Detects attended-profile footguns"

output=$("$DC_AUDIT" --profile attended --rubric "$RUBRIC" "$FIXTURES/attended-bad.json" 2>&1)
assert_contains "$output" "host-creds-mount-attended" "flags ~/.ssh bind mount in attended profile"
assert_contains "$output" "docker-sock-mount"          "flags docker.sock bind mount"
assert_contains "$output" "broad-home-mount"           "flags unscoped \$HOME bind mount"
assert_contains "$output" "runargs-privileged"         "flags --privileged"
assert_contains "$output" "runargs-cap-sys-admin"      "flags --cap-add=SYS_ADMIN"
assert_contains "$output" "runargs-seccomp-unconfined" "flags --security-opt=seccomp=unconfined"

# =================================================================
# Worktree-container rules
# =================================================================

test_suite "dc-audit: Detects worktree-hostile configuration"

output=$("$DC_AUDIT" --profile attended --rubric "$RUBRIC" "$FIXTURES/worktree-hostile.json" 2>&1)
assert_contains "$output" "workspace-mount-worktree-hostile" \
    "flags custom workspaceMount (breaks --mount-git-worktree-common-dir)"
assert_contains "$output" "fixed-volume-name-shared" \
    "flags fixed volume name as shared across per-worktree containers"

# The ${devcontainerId}-scoped mount alone must not fire the rule.
output=$("$DC_AUDIT" --profile attended --rubric "$RUBRIC" "$FIXTURES/minimal.json" 2>&1)
assert_not_contains "$output" "fixed-volume-name-shared" \
    "no fixed-volume finding without volume mounts"

test_suite "dc-audit: Detects os-provided git feature"

output=$("$DC_AUDIT" --profile attended --rubric "$RUBRIC" "$FIXTURES/git-os-provided.json" 2>&1)
assert_contains "$output" "git-feature-os-provided" \
    "flags git feature with no version (defaults to os-provided, can predate relativeWorktrees support)"
osp_count=$(printf '%s\n' "$output" | grep -c "git-feature-os-provided") || true
assert_equals 1 "$osp_count" "git-lfs and github-cli features do not fire the git rule"

# An explicit os-provided is the same failure as the default.
scratch=$(mktemp)
jq '.features["ghcr.io/devcontainers/features/git:1"].version = "os-provided"' \
    "$FIXTURES/git-os-provided.json" > "$scratch"
output=$("$DC_AUDIT" --profile attended --rubric "$RUBRIC" "$scratch" 2>&1)
assert_contains "$output" "git-feature-os-provided" "flags explicit version os-provided"

jq '.features["ghcr.io/devcontainers/features/git:1"].version = "latest"' \
    "$FIXTURES/git-os-provided.json" > "$scratch"
output=$("$DC_AUDIT" --profile attended --rubric "$RUBRIC" "$scratch" 2>&1)
assert_not_contains "$output" "git-feature-os-provided" "version latest passes"
rm -f "$scratch"

# No features block at all must not fire the rule.
output=$("$DC_AUDIT" --profile attended --rubric "$RUBRIC" "$FIXTURES/minimal.json" 2>&1)
assert_not_contains "$output" "git-feature-os-provided" "no finding without a features block"

# The shipped template example must audit clean at every severity.
output=$("$DC_AUDIT" --profile attended --strict --rubric "$RUBRIC" \
    "$DOTFILES_DIR/templates/worktree-project/devcontainer.json.example" 2>&1)
status=$?
assert_equals 0 "$status" "worktree-project devcontainer example passes strict audit"

# =================================================================
# Clean fixture
# =================================================================

test_suite "dc-audit: Clean unattended fixture passes"

output=$("$DC_AUDIT" --profile unattended --rubric "$RUBRIC" "$FIXTURES/unattended-clean.json" 2>&1)
rc=$?
assert_return_code 0 $? "clean fixture exits 0"
assert_not_contains "$output" "no-host-creds-unattended" "clean fixture has no host-creds finding"
assert_not_contains "$output" "cap-drop-unattended" "clean fixture has no cap-drop finding"

# =================================================================
# JSONC support
# =================================================================

test_suite "dc-audit: JSONC (comments) accepted"

output=$("$DC_AUDIT" --profile attended --rubric "$RUBRIC" "$FIXTURES/with-comments.json" 2>&1)
rc=$?
assert_not_contains "$output" "parse-error" "comments do not cause a parse error"
# The file is minimal; still expect a couple findings (no shutdownAction etc.)
assert_contains "$output" "shutdown-action" "rules still evaluate after comment stripping"

# =================================================================
# --fix idempotency + strictness
# =================================================================

test_suite "dc-audit: --fix applies and is idempotent"

scratch=$(mktemp)
cp "$FIXTURES/minimal.json" "$scratch"

# First pass: --fix --strict should succeed because fixed items are not
# counted as warnings any more.
out=$("$DC_AUDIT" --profile attended --rubric "$RUBRIC" --fix --strict "$scratch" 2>&1)
rc=$?
assert_return_code 0 "$rc" "--fix --strict exits 0 on first pass"
assert_contains "$out" "Fixed:" "summary reports a Fixed count"
assert_contains "$out" "[fixed]" "finding output marks [fixed]"

# Second pass: file is now clean, --strict should still succeed.
out2=$("$DC_AUDIT" --profile attended --rubric "$RUBRIC" --strict "$scratch" 2>&1)
rc2=$?
assert_return_code 0 "$rc2" "second pass on fixed file exits 0"
assert_not_contains "$out2" "[fixed]" "no further [fixed] lines on second pass"
assert_not_contains "$out2" "shutdown-action" "shutdownAction rule no longer fires"

rm -f "$scratch"

# =================================================================
# JSON output
# =================================================================

test_suite "dc-audit: JSON output"

out=$("$DC_AUDIT" --profile attended --rubric "$RUBRIC" --json "$FIXTURES/minimal.json" 2>&1)
# Every non-empty line should be valid JSON. The header/summary log lines go
# to a different stream (still captured by 2>&1 above) so we filter to lines
# that look like JSON objects.
line_count=$(printf '%s\n' "$out" | grep -c '^{"file"') || true
if [[ $line_count -gt 0 ]]; then
    test_pass "JSON output produced $line_count finding object(s)"
else
    test_fail "JSON output produced finding objects (got 0)"
fi
# Spot-check one line parses and has required keys.
first_json=$(printf '%s\n' "$out" | grep '^{"file"' | head -1)
if [[ -n "$first_json" ]]; then
    for field in file rule severity message status; do
        if ! jq -e "has(\"$field\")" <<<"$first_json" &>/dev/null; then
            test_fail "JSON finding has field: $field (missing in: $first_json)"
            break
        fi
    done
    if jq -e 'has("file") and has("rule") and has("severity") and has("message") and has("status")' <<<"$first_json" &>/dev/null; then
        test_pass "JSON finding has all required fields"
    fi
fi

# =================================================================
# Makefile lint-devcontainers profile mapping
# =================================================================
# Locks the contract: a devcontainer subdir whose basename is "unattended"
# is audited under --profile unattended; every other subdir under
# .devcontainer/ is audited under --profile attended. If someone swaps the
# case statement in the Makefile, or moves the unattended config elsewhere
# without updating the recipe, this test fires.

test_suite "dc-audit: Makefile lint-devcontainers profile mapping"

make_out=$(cd "$DOTFILES_DIR" && make -s lint-devcontainers 2>&1)
actual=$(printf '%s\n' "$make_out" \
    | sed 's/\x1b\[[0-9;]*m//g' \
    | grep -oE 'profile=[a-z]+' \
    | sed 's/profile=//' \
    | tr '\n' ' ')

expected=""
for d in "$DOTFILES_DIR"/.devcontainer/*/; do
    [[ -f "$d/devcontainer.json" ]] || continue
    name=$(basename "$d")
    if [[ "$name" == "unattended" ]]; then
        expected+="unattended "
    else
        expected+="attended "
    fi
done

if [[ "$actual" == "$expected" ]]; then
    test_pass "make lint-devcontainers profile sequence: $actual"
else
    test_fail "make lint-devcontainers profile sequence diverged. expected: '$expected' got: '$actual'"
fi

# --- Summary ---

print_test_summary
