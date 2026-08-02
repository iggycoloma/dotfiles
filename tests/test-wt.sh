#!/usr/bin/env bash
# Tests for bin/wt -- worktree operations for the agentic dev environment.
#
# Exercises both layouts against real (temporary) git repositories:
# orchestration mode (bare repo.git + local/ + state/ + wt/) and clone mode
# (sibling <repo>-worktrees/). The ignore-validation security invariant is
# tested first: provisioning must hard-fail on a non-ignored destination.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WT="$DOTFILES_DIR/bin/wt"

source "$SCRIPT_DIR/test-framework.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export HOME="$TMP/home"
mkdir -p "$HOME"
git config --global init.defaultBranch main
git config --global worktree.useRelativePaths true

# Seed remote: a bare repo with one commit on main, a .gitignore that
# ignores .env* so provisioning has legal destinations.
make_remote() {
    local remote="$1"
    git init -q --bare "$remote"
    local seed="$TMP/seed-$$-$RANDOM"
    git clone -q "$remote" "$seed" 2>/dev/null
    printf '.env\n.env.*\n' > "$seed/.gitignore"
    git -C "$seed" add -A
    git -C "$seed" commit -q -m init
    git -C "$seed" push -q origin HEAD
    rm -rf "$seed"
}

# ============================================================
# Test Suite: slug normalization
# ============================================================
test_suite "slug normalization"

# normalize_slug is internal; observe it through worktree paths in clone mode.
make_remote "$TMP/remote-slug.git"
git clone -q "$TMP/remote-slug.git" "$TMP/slugproj" 2>/dev/null
cd "$TMP/slugproj" || exit 1

dest=$("$WT" add "Feature/CLK-943_Fancy Name" 2>/dev/null)
assert_equals "$TMP/slugproj-worktrees/clk-943_fancy-name" "$dest" \
    "mixed-case path segment normalizes to lowercase leaf slug"
assert_file_exists "$dest/.git" "worktree created at normalized path"

# ============================================================
# Test Suite: clone mode
# ============================================================
test_suite "clone mode"

pointer=$(cat "$dest/.git")
assert_contains "$pointer" "gitdir: ../../" "clone-mode worktree pointer is relative"

cd "$dest" || exit 1
dest2=$("$WT" add second 2>/dev/null)
assert_equals "$TMP/slugproj-worktrees/second" "$dest2" \
    "running from inside a worktree keeps the sibling tree flat"

listing=$("$WT" list 2>/dev/null)
assert_contains "$listing" "slugproj-worktrees/second" "wt list shows created worktrees"

cd "$TMP/slugproj" || exit 1
"$WT" remove second >/dev/null 2>&1
assert_file_not_exists "$TMP/slugproj-worktrees/second/.git" "wt remove deletes a clean worktree"

# ============================================================
# Test Suite: orchestration mode
# ============================================================
test_suite "orchestration mode"

make_remote "$TMP/remote-orch.git"
cd "$TMP" || exit 1
root=$("$WT" init "$TMP/remote-orch.git" "$TMP/proj" 2>/dev/null)
assert_equals "$TMP/proj" "$root" "wt init prints the orchestration root"
assert_dir_exists "$TMP/proj/repo.git" "init creates bare repo.git"
assert_dir_exists "$TMP/proj/local/shared" "init creates local/shared"
assert_dir_exists "$TMP/proj/local/template" "init creates local/template"
assert_dir_exists "$TMP/proj/state" "init creates state/"
assert_dir_exists "$TMP/proj/main" "init creates the main worktree"

# shellcheck disable=SC2012
perms=$(ls -ld "$TMP/proj/local" | cut -c1-10)
assert_equals "drwx------" "$perms" "local/ is chmod 700"

rel=$(git --git-dir="$TMP/proj/repo.git" config worktree.useRelativePaths)
assert_equals "true" "$rel" "init sets worktree.useRelativePaths on repo.git"

cd "$TMP/proj" || exit 1
dest=$("$WT" add issue-123 2>/dev/null)
assert_equals "$TMP/proj/wt/issue-123" "$dest" "orchestration worktrees land in wt/"
pointer=$(cat "$dest/.git")
assert_contains "$pointer" "gitdir: ../../repo.git/worktrees/" \
    "orchestration pointer is relative into repo.git"

cd "$TMP/proj/wt/issue-123" || exit 1
nested=$("$WT" add from-inside 2>/dev/null)
assert_equals "$TMP/proj/wt/from-inside" "$nested" \
    "mode detection walks up: add from inside a worktree stays in wt/"

# ============================================================
# Test Suite: provisioning and the ignore-validation invariant
# ============================================================
test_suite "provisioning security invariant"

cd "$TMP/proj" || exit 1
printf 'SANDBOX_KEY=abc\n' > local/shared/.env.shared
printf 'LOCAL_SEED=1\n'    > local/template/.env.local

dest=$("$WT" add provisioned 2>/dev/null)
assert_file_exists "$dest/.env.shared" "shared file provisioned into new worktree"
assert_file_exists "$dest/.env.local" "template file provisioned into new worktree"

printf 'CUSTOMIZED=1\n' > "$dest/.env.local"
printf 'SANDBOX_KEY=xyz\n' > local/shared/.env.shared

# Non-ignored destination must abort the whole add and roll back.
printf 'oops\n' > local/shared/not-ignored.txt
output=$("$WT" add rejected 2>&1)
status=$?
assert_not_equals 0 "$status" "add fails when a local file destination is not gitignored"
assert_contains "$output" "non-ignored" "failure names the offending file"
assert_file_not_exists "$TMP/proj/wt/rejected/.git" "failed add rolls the worktree back"
rm -f local/shared/not-ignored.txt

# ============================================================
# Test Suite: sync and diff-local
# ============================================================
test_suite "sync and diff-local"

cd "$TMP/proj" || exit 1
dest="$TMP/proj/wt/provisioned"

# shared drifted earlier (SANDBOX_KEY=xyz written after provisioning abc)
output=$("$WT" diff-local provisioned 2>&1)
status=$?
assert_not_equals 0 "$status" "diff-local exits nonzero on drift"
assert_contains "$output" "differs" "diff-local reports the drifted file"

"$WT" sync provisioned >/dev/null 2>&1
synced=$(cat "$dest/.env.shared")
assert_equals "SANDBOX_KEY=xyz" "$synced" "sync overwrites shared copies"
customized=$(cat "$dest/.env.local")
assert_equals "CUSTOMIZED=1" "$customized" "sync leaves customized template files alone"

output=$("$WT" diff-local provisioned 2>&1)
assert_equals 0 $? "diff-local passes after sync"

# ============================================================
# Test Suite: runtime identity and port registry
# ============================================================
test_suite "runtime identity"

assert_file_exists "$dest/.env.worktree" "add generates .env.worktree"
env_content=$(cat "$dest/.env.worktree")
assert_contains "$env_content" "WORKTREE_SLUG=provisioned" "env has slug"
assert_contains "$env_content" "COMPOSE_PROJECT_NAME=proj-provisioned" "env has compose project name"
port1=$(sed -n 's/^APP_PORT=//p' "$dest/.env.worktree")
assert_contains "$env_content" "APP_PORT=$port1" "worktree gets a port from the registry"

dest2=$("$WT" add second-id 2>/dev/null)
port2=$(sed -n 's/^APP_PORT=//p' "$dest2/.env.worktree")
assert_equals "$((port1 + 1))" "$port2" "next worktree gets the next free port"

"$WT" remove second-id --branch >/dev/null 2>&1
if grep -q "second-id" "$TMP/proj/state/ports.tsv"; then
    released="no"
else
    released="yes"
fi
assert_equals "yes" "$released" "remove releases the allocated port"

# ============================================================
# Test Suite: container command gating
# ============================================================
test_suite "container gating"

if [[ -f /.dockerenv ]]; then
    output=$("$WT" container-up provisioned 2>&1)
    status=$?
    assert_not_equals 0 "$status" "container-up refuses to run inside a container"
    assert_contains "$output" "host-only" "refusal explains containers never launch containers"
    output=$("$WT" exec provisioned -- true 2>&1)
    assert_not_equals 0 $? "exec refuses to run inside a container"
else
    output=$("$WT" container-up 2>&1)
    assert_not_equals 0 $? "container-up requires a name"
fi

# ============================================================
# Test Suite: remove safety
# ============================================================
test_suite "remove safety"

printf 'work in progress\n' > "$TMP/proj/wt/issue-123/wip.txt"
output=$("$WT" remove issue-123 2>&1)
status=$?
assert_not_equals 0 "$status" "remove refuses a worktree with untracked files"
assert_contains "$output" "untracked" "refusal names the reason"
assert_file_exists "$TMP/proj/wt/issue-123/wip.txt" "refused remove leaves work intact"

rm -f "$TMP/proj/wt/issue-123/wip.txt"
"$WT" remove issue-123 --branch >/dev/null 2>&1
assert_file_not_exists "$TMP/proj/wt/issue-123/.git" "clean worktree removes"
if git --git-dir="$TMP/proj/repo.git" show-ref --verify --quiet refs/heads/issue-123; then
    branch_gone="no"
else
    branch_gone="yes"
fi
assert_equals "yes" "$branch_gone" "--branch also deletes the branch"

# ============================================================
# Test Suite: doctor
# ============================================================
test_suite "doctor"

cd "$TMP/proj" || exit 1
output=$("$WT" doctor 2>&1)
status=$?
assert_equals 0 "$status" "doctor passes on a healthy orchestration dir"
assert_contains "$output" "mode: orchestration" "doctor reports orchestration mode"
assert_contains "$output" "useRelativePaths: true" "doctor confirms relative paths config"

# ============================================================
# Summary
# ============================================================
print_test_summary
