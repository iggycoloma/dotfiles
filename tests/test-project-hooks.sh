#!/usr/bin/env bash
# Behavioral tests for the opt-in project-hook chaining in the global
# dispatcher hooks (git/hooks/{pre-commit,commit-msg,pre-push,post-checkout}).
#
# A repo opts in with `git config dotfiles.projectHooks true`; each global
# dispatcher then chains the repo's tracked .githooks/<hook>. This is the
# supported alternative to repo-local core.hooksPath, which would replace
# the dispatchers entirely and silently disable secret scanning. The flag
# is read with --local only: the trust grant must live in the repository's
# own config, which a clone cannot ship.
#
# Strategy: build a throwaway repo per suite, point the dispatcher at a
# .githooks hook that drops a marker file, and flip the config bit.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$DOTFILES_DIR/git/hooks"

source "$SCRIPT_DIR/test-framework.sh"

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# Isolate from the developer's real git config at file scope (as
# test-signing.sh and test-wt.sh do): the user's core.hooksPath, commit
# signing, or a stray dotfiles.projectHooks must not leak into repo setup
# or the dispatchers under test. The scope tests below write into this
# throwaway global config deliberately.
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$TMP_ROOT/gitconfig-global"
: > "$GIT_CONFIG_GLOBAL"

# Fresh repo with a tracked-style .githooks/<hook> that records its
# invocation (arguments included) in marker. Prints the repo path.
make_repo() {
    local name="$1" hook="$2"
    local repo="$TMP_ROOT/$name"
    mkdir -p "$repo/.githooks"
    git -C "$TMP_ROOT" init -q "$name"
    git -C "$repo" config user.email t@example.com
    git -C "$repo" config user.name t
    git -C "$repo" commit -q --allow-empty -m 'chore: base' --no-verify
    cat > "$repo/.githooks/$hook" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$repo/marker"
EOF
    chmod +x "$repo/.githooks/$hook"
    printf '%s\n' "$repo"
}

# Run a dispatcher from inside the repo with a clean recursion guard and
# stdin closed (pre-push reads stdin; the others ignore it). Config
# isolation comes from the file-scope exports above.
run_dispatcher() {
    local repo="$1" hook="$2"
    shift 2
    (cd "$repo" && env -u DOTFILES_GLOBAL_HOOK_RUNNING \
        bash "$HOOKS_DIR/$hook" "$@" < /dev/null)
}

for hook in pre-commit commit-msg pre-push post-checkout; do
    test_suite "project hooks: $hook chaining"

    repo=$(make_repo "repo-$hook" "$hook")

    case "$hook" in
        commit-msg)    msg_file="$repo/msg"; printf 'feat: chained\n' > "$msg_file"; args=("$msg_file") ;;
        pre-push)      args=(origin git@example.com:o/r.git) ;;
        # Non-zero old ref: the initial-checkout provisioning path is wt's,
        # not this test's.
        post-checkout) args=(1111111111111111111111111111111111111111 2222222222222222222222222222222222222222 1) ;;
        *)             args=() ;;
    esac

    run_dispatcher "$repo" "$hook" ${args[@]+"${args[@]}"} >/dev/null 2>&1
    rc=$?
    assert_equals 0 "$rc" "$hook exits 0 without the opt-in"
    if [[ -f "$repo/marker" ]]; then
        test_fail "$hook does not run .githooks/$hook without the opt-in"
    else
        test_pass "$hook does not run .githooks/$hook without the opt-in"
    fi

    # The trust grant is per-repository: a global-scope flag would make
    # every cloned repo's .githooks run, so the dispatchers must ignore it.
    git config --file "$GIT_CONFIG_GLOBAL" dotfiles.projectHooks true
    run_dispatcher "$repo" "$hook" ${args[@]+"${args[@]}"} >/dev/null 2>&1
    rc=$?
    git config --file "$GIT_CONFIG_GLOBAL" --unset dotfiles.projectHooks
    assert_equals 0 "$rc" "$hook exits 0 with only a global-scope flag"
    if [[ -f "$repo/marker" ]]; then
        test_fail "$hook ignores a global-scope dotfiles.projectHooks"
    else
        test_pass "$hook ignores a global-scope dotfiles.projectHooks"
    fi

    git -C "$repo" config dotfiles.projectHooks true
    run_dispatcher "$repo" "$hook" ${args[@]+"${args[@]}"} >/dev/null 2>&1
    rc=$?
    assert_equals 0 "$rc" "$hook exits 0 with the opt-in"
    if [[ -f "$repo/marker" ]]; then
        test_pass "$hook runs .githooks/$hook when dotfiles.projectHooks=true"
    else
        test_fail "$hook runs .githooks/$hook when dotfiles.projectHooks=true"
    fi

    printf '#!/usr/bin/env bash\nexit 7\n' > "$repo/.githooks/$hook"
    run_dispatcher "$repo" "$hook" ${args[@]+"${args[@]}"} >/dev/null 2>&1
    rc=$?
    assert_equals 7 "$rc" "$hook propagates a failing project hook's exit code"

    # Opted in with the hook present but not executable: the one state where
    # the owner believes project checks run and they do not. Git warns for
    # its own non-executable hooks; the dispatchers match that -- skip, warn
    # on stderr, and keep going.
    chmod -x "$repo/.githooks/$hook"
    stderr=$(run_dispatcher "$repo" "$hook" ${args[@]+"${args[@]}"} 2>&1 >/dev/null)
    rc=$?
    assert_equals 0 "$rc" "$hook exits 0 when the project hook is not executable"
    assert_contains "$stderr" "not executable" \
        "$hook warns about a present but non-executable project hook"
    chmod +x "$repo/.githooks/$hook"

    git -C "$repo" config dotfiles.projectHooks false
    run_dispatcher "$repo" "$hook" ${args[@]+"${args[@]}"} >/dev/null 2>&1
    rc=$?
    assert_equals 0 "$rc" "$hook honors an explicit false as opted out"
done

test_suite "project hooks: worktree resolution"

# The dispatcher must run the *current worktree's* copy of the hook, not the
# main checkout's: linked worktrees share config through the common dir, so
# the opt-in carries over, but --show-toplevel differs per checkout.
repo=$(make_repo "repo-worktree" "pre-commit")
git -C "$repo" config dotfiles.projectHooks true
git -C "$repo" add .githooks
git -C "$repo" commit -qm 'chore: githooks' --no-verify
git -C "$repo" worktree add -q "$TMP_ROOT/linked" -b linked
mkdir -p "$TMP_ROOT/linked/.githooks"
cat > "$TMP_ROOT/linked/.githooks/pre-commit" <<EOF
#!/usr/bin/env bash
touch "$TMP_ROOT/linked-marker"
EOF
chmod +x "$TMP_ROOT/linked/.githooks/pre-commit"
run_dispatcher "$TMP_ROOT/linked" pre-commit >/dev/null 2>&1
if [[ -f "$TMP_ROOT/linked-marker" && ! -f "$repo/marker" ]]; then
    test_pass "linked worktree runs its own .githooks copy"
else
    test_fail "linked worktree runs its own .githooks copy"
fi

print_test_summary
