#!/usr/bin/env bash
# Contract tests for the global pre-push dispatcher.

set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-framework.sh"

HOOK="$DOTFILES_DIR/git/hooks/pre-push"
test_suite "pre-push hook structure"
bash -n "$HOOK"
assert_return_code 0 $? "pre-push passes bash -n"
assert_contains "$(cat "$HOOK")" "git lfs pre-push" "pre-push preserves Git LFS"
assert_contains "$(cat "$HOOK")" "pre-push.local" "pre-push delegates repository policy"
assert_contains "$(cat "$HOOK")" "gitleaks git" "pre-push scans outgoing commits"
assert_contains "$(cat "$HOOK")" "--redact" "pre-push redacts detected secrets"

test_suite "pre-push outgoing commit selection"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/pre-push-test.XXXXXX")
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/repo"
cat > "$fixture/bin/git-lfs" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$fixture/bin/gitleaks" <<'SH'
#!/usr/bin/env bash
for arg in "$@"; do
    if [[ "$arg" == --log-opts=* ]]; then
        read -r -a revisions <<< "${arg#--log-opts=}"
    fi
done
git rev-list "${revisions[@]}" > "$SCAN_FILE" || exit 2
if [[ -n "${BLOCKED_COMMIT:-}" ]] && grep -qF "$BLOCKED_COMMIT" "$SCAN_FILE"; then
    exit 1
fi
SH
chmod +x "$fixture/bin/git-lfs" "$fixture/bin/gitleaks"
export PATH="$fixture/bin:$PATH"
export SCAN_FILE="$fixture/scanned"
export GIT_AUTHOR_NAME=Test GIT_COMMITTER_NAME=Test
export GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_EMAIL=test@example.invalid
git -C "$fixture/repo" init -q
empty_tree=$(git -C "$fixture/repo" mktree < /dev/null)
commit() {
    local subject="$1"
    shift
    printf '%s\n' "$subject" | git -C "$fixture/repo" commit-tree "$empty_tree" "$@"
}
base=$(commit base)
upstream=$(commit upstream -p "$base")
old=$(commit old-feature -p "$base")
rebased=$(commit rebased-feature -p "$upstream")
new=$(commit new-feature -p "$old")
git -C "$fixture/repo" update-ref refs/remotes/origin/main "$upstream"
git -C "$fixture/repo" update-ref refs/remotes/origin/topic "$old"
git -C "$fixture/repo" update-ref refs/remotes/other/topic "$rebased"
zero=0000000000000000000000000000000000000000
scan() {
    : > "$SCAN_FILE"
    (cd "$fixture/repo" && bash "$HOOK" origin unused <<< "$1") > "$fixture/output" 2>&1
}
export BLOCKED_COMMIT="$upstream"
scan "refs/heads/topic $rebased refs/heads/topic $old"
assert_return_code 0 $? "rebase excludes commits already on destination main"
assert_equals "$rebased" "$(cat "$SCAN_FILE")" "rebase scans only the unpublished feature commit"
scan "refs/heads/topic $rebased refs/heads/topic $zero"
assert_return_code 0 $? "new branch excludes destination history"
assert_equals "$rebased" "$(cat "$SCAN_FILE")" "other remotes do not exclude outgoing commits"
export BLOCKED_COMMIT="$new"
scan "refs/heads/topic $new refs/heads/topic $old"
assert_return_code 1 $? "newly introduced finding still blocks update"
assert_equals "$new" "$(cat "$SCAN_FILE")" "fast-forward scans the new commit"
scan "refs/heads/topic $new refs/heads/topic $zero"
assert_return_code 1 $? "newly introduced finding still blocks new branch"
scan "refs/heads/topic $zero refs/heads/topic $old"
assert_return_code 0 $? "branch deletion does not scan history"
assert_equals "" "$(cat "$SCAN_FILE")" "deletion invokes no scan"
git -C "$fixture/repo" update-ref -d refs/remotes/origin/topic
scan "refs/heads/topic $new refs/heads/topic $old"
assert_return_code 1 $? "advertised remote tip is excluded without a tracking ref"
assert_equals "$new" "$(cat "$SCAN_FILE")" "advertised tip exclusion does not depend on tracking refs"
scan "refs/heads/main $upstream refs/heads/main $upstream"
assert_return_code 0 $? "already published tip has no outgoing commits"
assert_equals "" "$(cat "$SCAN_FILE")" "empty range remains empty"
scan "refs/heads/topic $new refs/heads/topic 1111111111111111111111111111111111111111"
assert_return_code 1 $? "missing advertised remote object fails closed"
scan "refs/heads/rebased $rebased refs/heads/rebased $old
refs/heads/new $new refs/heads/new $old"
assert_return_code 1 $? "finding on second updated ref blocks the push"

print_test_summary
