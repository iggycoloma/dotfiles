#!/usr/bin/env bash
# Behavioral tests for .githooks/pre-commit, which regenerates derived files
# (claude-code/settings.container.json, docs/prompt-stats.md) in the commit
# that changes their inputs.
#
# Strategy: copy this checkout's files into a throwaway repository so the
# generators run against real inputs, make a derived file stale, and run the
# hook both directly and through the global pre-commit dispatcher.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/test-framework.sh"

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

export GIT_CONFIG_SYSTEM=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$TMP_ROOT/gitconfig-global"
: > "$GIT_CONFIG_GLOBAL"

# An inherited DOTFILES_DIR names the developer's real checkout; the hook must
# override it, so leave a wrong value in place to prove that it does.
export DOTFILES_DIR="$TMP_ROOT/not-the-repo"

new_repo() {
    local repo="$TMP_ROOT/$1"
    mkdir -p "$repo"
    (cd "$SOURCE_DIR" && git ls-files -z --cached --others --exclude-standard \
        | tar --null -T - -cf -) | tar -xf - -C "$repo"
    git -C "$repo" init -q
    git -C "$repo" config user.email t@example.com
    git -C "$repo" config user.name t
    git -C "$repo" config commit.gpgsign false
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "chore: baseline"
    printf '%s' "$repo"
}

staged_files() {
    git -C "$1" diff --cached --name-only
}

grow_prompt_source() {
    printf '\nAn extra sentence that changes the byte count enough to move the token estimate.\n' \
        >> "$1/agent-prompts/forge.md"
}

add_allow_rule() {
    local settings="$1/claude-code/settings.json"
    jq '.permissions.allow += ["Bash(true:*)"]' "$settings" > "$settings.tmp" \
        && mv "$settings.tmp" "$settings"
}

test_suite "Stale prompt stats"

repo=$(new_repo stats)
grow_prompt_source "$repo"
git -C "$repo" add agent-prompts/forge.md
(cd "$repo" && .githooks/pre-commit) 2>/dev/null
assert_equals "0" "$?" "The hook exits 0 after regenerating"
assert_contains "$(staged_files "$repo")" "docs/prompt-stats.md" \
    "The regenerated stats are staged with the prompt edit"
assert_command_succeeds "The staged stats satisfy the lint gate" \
    "$repo/bin/prompt-stats.sh" --check

test_suite "Stale container settings"

repo=$(new_repo settings)
add_allow_rule "$repo"
git -C "$repo" add claude-code/settings.json
(cd "$repo" && .githooks/pre-commit) 2>/dev/null
assert_contains "$(staged_files "$repo")" "claude-code/settings.container.json" \
    "The regenerated container settings are staged with the host edit"
assert_command_succeeds "The staged container settings satisfy the lint gate" \
    env DOTFILES_DIR="$repo" "$repo/bin/sync-settings.sh" --check

test_suite "Nothing stale"

repo=$(new_repo current)
printf 'note\n' > "$repo/unrelated.txt"
git -C "$repo" add unrelated.txt
(cd "$repo" && .githooks/pre-commit) 2>/dev/null
assert_equals "unrelated.txt" "$(staged_files "$repo")" \
    "A commit that leaves derived files current stages nothing extra"

test_suite "Unstaged changes present"

repo=$(new_repo dirty)
grow_prompt_source "$repo"
git -C "$repo" add agent-prompts/forge.md
printf '\nUnstaged edit.\n' >> "$repo/AGENTS.md"
hook_stderr=$( (cd "$repo" && .githooks/pre-commit) 2>&1 >/dev/null)
assert_equals "0" "$?" "The hook never blocks the commit"
assert_not_contains "$(staged_files "$repo")" "docs/prompt-stats.md" \
    "Stats computed from unstaged content are not staged"
assert_contains "$hook_stderr" "unstaged changes are present" \
    "The hook says why it left the stale file alone"

test_suite "Through the global dispatcher"

repo=$(new_repo dispatched)
git -C "$repo" config dotfiles.projectHooks true
grow_prompt_source "$repo"
git -C "$repo" add agent-prompts/forge.md
(cd "$repo" && "$repo/git/hooks/pre-commit") >/dev/null 2>&1
assert_contains "$(staged_files "$repo")" "docs/prompt-stats.md" \
    "The opted-in dispatcher chains the hook"

repo=$(new_repo not-opted-in)
grow_prompt_source "$repo"
git -C "$repo" add agent-prompts/forge.md
(cd "$repo" && "$repo/git/hooks/pre-commit") >/dev/null 2>&1
assert_not_contains "$(staged_files "$repo")" "docs/prompt-stats.md" \
    "Without the opt-in the hook does not run"

print_test_summary
