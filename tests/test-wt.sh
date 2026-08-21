#!/usr/bin/env bash
# Integration tests for this repo's wt wiring: the post-checkout safety-net
# hook, the Claude Code worktree shims, and zsh completion registration.
#
# wt itself lives in https://github.com/iggycoloma/worktree-orchestrator,
# which owns the tool's unit suite; these tests exercise the dotfiles files
# that call into the installed wt, so they need bootstrap/wt.sh to have run.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/test-framework.sh"

# Resolve the installed wt (and its completions, which live beside bin/ in
# the clone) before HOME is redirected below.
WT="${WT_BIN:-$HOME/.local/bin/wt}"
if [[ ! -x "$WT" ]]; then
    echo "wt not installed at $WT -- run bootstrap/wt.sh; skipping integration tests"
    exit 0
fi
WT_COMP_DIR="$(cd "$(dirname "$(readlink -f "$WT")")/../completions" 2>/dev/null && pwd)"

TMP="$(mktemp -d)"
# git reports worktree paths with symlinks resolved, and on macOS mktemp
# returns /var/... which is a symlink to /private/var/..., so unresolved
# expectations would never match wt's output. Resolve once here.
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
# The host shell may export this (a dotfiles setup does); wt's dotfiles_repo
# reads it, so a leaked value changes container-flag behavior.
unset WT_DOTFILES_REPOSITORY
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

GIT_REL_OK=0
bash -c "source '$WT' && version_at_least \"\$(command git --version | awk '{print \$3}')\" 2.48.0" && GIT_REL_OK=1

# Pointer assertions must hold on new git and degrade with old git.
assert_rel_pointer() {
    local gitfile="$1" label="$2"
    if [[ "$GIT_REL_OK" -eq 1 ]]; then
        assert_contains "$(cat "$gitfile")" "gitdir: ../" "$label"
    else
        assert_file_exists "$gitfile" "$label (absolute-pointer fallback on old git)"
    fi
}

# Fixtures: a clone-mode repo (slugproj) for the shim fallback paths, and an
# orchestration layout (proj) with a provisionable local/shared file.
make_remote "$TMP/remote-slug.git"
git clone -q "$TMP/remote-slug.git" "$TMP/slugproj" 2>/dev/null

make_remote "$TMP/remote-orch.git"
cd "$TMP" || exit 1
"$WT" init "$TMP/remote-orch.git" "$TMP/proj" >/dev/null 2>&1
printf 'SANDBOX_KEY=abc\n' > "$TMP/proj/local/shared/.env.shared"
cd "$TMP/proj" || exit 1

# ============================================================
# Test Suite: post-checkout safety-net hook
# ============================================================
test_suite "post-checkout hook"

HOOK="$DOTFILES_DIR/git/hooks/post-checkout"
export WT_BIN="$WT"
NULL_REF="0000000000000000000000000000000000000000"

# A worktree created OUTSIDE wt (plain git) gets provisioned by the hook.
# No explicit --relative-paths: the global useRelativePaths config covers
# new git, and old git must not fail on an unknown flag here.
git --git-dir="$TMP/proj/repo.git" worktree add -q \
    -b outside "$TMP/proj/wt/outside" main 2>/dev/null
head_ref=$(git -C "$TMP/proj/wt/outside" rev-parse HEAD)
assert_file_not_exists "$TMP/proj/wt/outside/.env.shared" \
    "plain git worktree add does not provision by itself"
(cd "$TMP/proj/wt/outside" && bash "$HOOK" "$NULL_REF" "$head_ref" 1)
assert_equals 0 $? "hook exits 0 on initial checkout"
assert_file_exists "$TMP/proj/wt/outside/.env.shared" \
    "hook provisions local/shared into an externally created worktree"

# Ordinary branch switch (non-null old ref) must be a no-op.
rm -f "$TMP/proj/wt/outside/.env.shared"
(cd "$TMP/proj/wt/outside" && bash "$HOOK" "$head_ref" "$head_ref" 1)
assert_file_not_exists "$TMP/proj/wt/outside/.env.shared" \
    "hook ignores ordinary branch switches"

# File checkout (kind 0) must be a no-op.
(cd "$TMP/proj/wt/outside" && bash "$HOOK" "$NULL_REF" "$head_ref" 0)
assert_file_not_exists "$TMP/proj/wt/outside/.env.shared" \
    "hook ignores file checkouts"

# A non-slug directory name still round-trips: the hook passes the path
# and resolve_worktree accepts absolute paths.
git --git-dir="$TMP/proj/repo.git" worktree add -q \
    -b feature-x "$TMP/proj/wt/Feature_X" main 2>/dev/null
fx_ref=$(git -C "$TMP/proj/wt/Feature_X" rev-parse HEAD)
(cd "$TMP/proj/wt/Feature_X" && bash "$HOOK" "$NULL_REF" "$fx_ref" 1)
assert_file_exists "$TMP/proj/wt/Feature_X/.env.shared" \
    "hook provisions worktrees whose directory name is not a slug"

# Clone-mode worktrees (no orchestration local/) exit silently.
output=$(cd "$TMP/slugproj" && bash "$HOOK" "$NULL_REF" "$head_ref" 1 2>&1)
assert_equals 0 $? "hook exits 0 outside orchestration layout"
assert_equals "" "$output" "hook is silent outside orchestration layout"

unset WT_BIN

# ============================================================
# Test Suite: WorktreeCreate / WorktreeRemove shims
# ============================================================
test_suite "harness shims"

CREATE_SHIM="$DOTFILES_DIR/claude-code/hooks/worktree-create.sh"
REMOVE_SHIM="$DOTFILES_DIR/claude-code/hooks/worktree-remove.sh"
export WT_BIN="$WT"

shim_json() {
    jq -n -c --arg base "$1" --arg suffix "$2" --arg cwd "$3" \
        '{worktree_base_path: $base, worktree_suffix: $suffix, cwd: $cwd}'
}

# Orchestration repo: shim routes through wt, path lands in wt/.
path=$(shim_json "$TMP/proj/.claude/worktrees" "claude-abc" "$TMP/proj" | bash "$CREATE_SHIM" 2>/dev/null)
assert_equals 0 $? "create shim exits 0 via wt"
assert_equals "$TMP/proj/wt/claude-abc" "$path" "shim redirects creation into wt/, not .claude/worktrees"
assert_file_exists "$path/.env.shared" "shim-created worktree is provisioned"

# Reuse: same suffix returns the existing worktree.
path2=$(shim_json "$TMP/proj/.claude/worktrees" "claude-abc" "$TMP/proj" | bash "$CREATE_SHIM" 2>/dev/null)
assert_equals "$path" "$path2" "shim is idempotent for an existing name"

# Security abort: non-ignored local file must abort creation, not degrade.
printf 'oops\n' > "$TMP/proj/local/shared/bad.txt"
shim_json "$TMP/proj/.claude/worktrees" "claude-sec" "$TMP/proj" | bash "$CREATE_SHIM" >/dev/null 2>&1
assert_not_equals 0 $? "create shim aborts on ignore-validation failure"
assert_file_not_exists "$TMP/proj/wt/claude-sec/.git" "aborted creation leaves no worktree"
rm -f "$TMP/proj/local/shared/bad.txt"

# Degrade: wt unavailable falls back to plain git worktree add at the base path.
path=$(shim_json "$TMP/slugproj/.claude/worktrees" "claude-fb" "$TMP/slugproj" | WT_BIN=/nonexistent/wt bash "$CREATE_SHIM" 2>/dev/null)
assert_equals "$TMP/slugproj/.claude/worktrees/claude-fb" "$path" "shim degrades to git worktree add at the suggested base"
assert_rel_pointer "$path/.git" "fallback worktree still gets a relative pointer"

# A leftover branch from an earlier worktree must not abort the fallback.
git -C "$TMP/slugproj" branch worktree-claude-fb2 2>/dev/null
path=$(shim_json "$TMP/slugproj/.claude/worktrees" "claude-fb2" "$TMP/slugproj" | WT_BIN=/nonexistent/wt bash "$CREATE_SHIM" 2>/dev/null)
assert_equals "$TMP/slugproj/.claude/worktrees/claude-fb2" "$path" "fallback uniquifies a colliding branch instead of aborting"

# Remove shim: tears down a clean wt-managed worktree, always exits 0.
printf '%s' "{\"worktree_path\": \"$TMP/proj/wt/claude-abc\"}" | bash "$REMOVE_SHIM" >/dev/null 2>&1
assert_equals 0 $? "remove shim exits 0"
assert_file_not_exists "$TMP/proj/wt/claude-abc/.git" "remove shim removes the worktree"

# Dirty worktree: refused by wt, shim still exits 0 and preserves work.
dirty=$("$WT" add dirty-one 2>/dev/null)
printf 'wip\n' > "$dirty/wip.txt"
printf '%s' "{\"worktree_path\": \"$dirty\"}" | bash "$REMOVE_SHIM" >/dev/null 2>&1
assert_equals 0 $? "remove shim exits 0 even when removal is refused"
assert_file_exists "$dirty/wip.txt" "refused removal preserves uncommitted work"

unset WT_BIN

# ============================================================
# Test Suite: zsh completion registration
# ============================================================
test_suite "zsh completion registration"

# Registration is a separate failure from the completion's own logic: a healthy
# _wt that compinit never scans leaves `wt <TAB>` on zsh's _files fallback,
# which looks like cwd names. Every link in that chain is checked here, because
# each one has its own way of breaking while the other tests stay green.

# Link one: .zshrc must put the completions dir on fpath BEFORE compinit.
# completions.zsh also sets fpath, but completion.sh sources it after compinit.
zshrc_fpath_line=$(grep -n 'fpath=(' "$DOTFILES_DIR/shell/.zshrc" | head -1 | cut -d: -f1)
zshrc_compinit_line=$(grep -n '^[[:space:]]*compinit' "$DOTFILES_DIR/shell/.zshrc" | head -1 | cut -d: -f1)
assert_not_equals "" "$zshrc_fpath_line" ".zshrc adds the completions dir to fpath itself"
[[ -n "$zshrc_fpath_line" && -n "$zshrc_compinit_line" && \
    "$zshrc_fpath_line" -lt "$zshrc_compinit_line" ]] && ordered=yes || ordered=no
assert_equals "yes" "$ordered" ".zshrc sets fpath before compinit runs"

# Link two: .zshrc scans the dir the installer writes to. The two compute their
# paths independently, so drift in either leaves every other check here passing
# while the completion is dead. Evaluate both expressions instead of comparing
# their text, under set and unset ZDOTDIR to cover the fallback branch too.
expand_expr() {
    if [[ -n "$2" ]]; then
        env -i HOME="$1" ZDOTDIR="$2" bash -c "printf '%s' $3"
    else
        env -i HOME="$1" bash -c "printf '%s' $3"
    fi
}

zshrc_dir_expr=$(grep -m1 '^_comp_dir=' "$DOTFILES_DIR/shell/.zshrc" | cut -d= -f2-)
zshrc_dump_expr=$(grep -m1 '^_comp_dump=' "$DOTFILES_DIR/shell/.zshrc" | cut -d= -f2-)
inst_dir_expr=$(grep -m1 'zsh_dir="' "$DOTFILES_DIR/bootstrap/completions.sh" | sed 's/.*zsh_dir=//')
inst_dump_expr=$(grep -m1 'comp_dump="' "$DOTFILES_DIR/bootstrap/completions.sh" | sed 's/.*comp_dump=//')
assert_not_equals "" "$zshrc_dir_expr" ".zshrc names the completions dir in _comp_dir"
assert_not_equals "" "$inst_dir_expr" "completions.sh names the completions dir in zsh_dir"
assert_not_equals "" "$zshrc_dump_expr" ".zshrc names the dump in _comp_dump"
assert_not_equals "" "$inst_dump_expr" "completions.sh names the dump in comp_dump"

for zdotdir in "" "/probe/zdot"; do
    if [[ -z "$zdotdir" ]]; then label="ZDOTDIR unset"; else label="ZDOTDIR=$zdotdir"; fi
    assert_equals \
        "$(expand_expr /probe/home "$zdotdir" "$inst_dir_expr")/completions" \
        "$(expand_expr /probe/home "$zdotdir" "$zshrc_dir_expr")" \
        ".zshrc and completions.sh agree on the completions dir ($label)"
    assert_equals \
        "$(expand_expr /probe/home "$zdotdir" "$inst_dump_expr")" \
        "$(expand_expr /probe/home "$zdotdir" "$zshrc_dump_expr")" \
        ".zshrc and completions.sh agree on the dump path ($label)"
done

# Link three: a cached dump must not outlive a change to the completions dir.
# `compinit -C` replays the dump without rescanning fpath, so without this the
# fpath entry above does nothing until the daily rebuild -- the installer can
# write _wt and `wt <TAB>` stays broken for a day. Run the real condition text
# rather than a copy, so a rewrite of it cannot pass by staying plausible.
comp_cond=$(grep -m1 '^if \[\[.*_comp_dump' "$DOTFILES_DIR/shell/.zshrc")
assert_not_equals "" "$comp_cond" ".zshrc guards compinit with a rebuild condition"

if command -v zsh >/dev/null 2>&1 && [[ -n "$comp_cond" ]]; then
    # Both dumps are written now, so they stay inside the 24h window and only
    # the dir comparison can decide. The dirs get fixed timestamps rather than
    # creation order: mtime granularity is coarse enough on some filesystems
    # for two consecutive creations to tie. -t CCYYMMDDhhmm is the one touch
    # format GNU, BSD, and busybox all accept.
    mkdir -p "$TMP/cached_dir" "$TMP/stale_dir"
    echo dump > "$TMP/cached_dump"
    echo dump > "$TMP/stale_dump"
    touch -t 202001010000 "$TMP/cached_dir"
    touch -t 203001010000 "$TMP/stale_dir"

    for case_name in cached stale; do
        {
            printf '%s\n' 'setopt EXTENDED_GLOB'
            printf '_comp_dir=%s\n' "$TMP/${case_name}_dir"
            printf '_comp_dump=%s\n' "$TMP/${case_name}_dump"
            printf '%s\n' "$comp_cond" '    print rebuild' 'else' '    print cached' 'fi'
        } > "$TMP/cond_$case_name.zsh"
    done

    assert_equals "cached" "$(zsh -f "$TMP/cond_cached.zsh" 2>/dev/null)" \
        "a fresh dump newer than the completions dir uses the cached path"
    assert_equals "rebuild" "$(zsh -f "$TMP/cond_stale.zsh" 2>/dev/null)" \
        "a completions dir newer than the dump forces a full compinit"
else
    echo "  (zsh not installed -- skipping dump-staleness check)"
fi

# The installer closes the same gap from its side, for shells whose .zshrc
# predates the check and for coarse-mtime filesystems.
# shellcheck disable=SC2016  # matching the literal source text, not expanding it
assert_contains "$(cat "$DOTFILES_DIR/bootstrap/completions.sh")" 'rm -f "$comp_dump"' \
    "completions.sh drops the dump after installing completions"

# Link four: carapace ships a colliding `wt` spec (Windows Terminal) and
# mass-registers every spec after our compdef, so the exclusion is what keeps
# the binding. It must live in exports.sh -- completion.sh is too late, it runs
# `carapace _carapace <shell>` itself.
assert_contains "$(cat "$DOTFILES_DIR/shell/exports.sh")" "CARAPACE_EXCLUDES" \
    "exports.sh sets CARAPACE_EXCLUDES"
carapace_in_completion=$(grep -c 'CARAPACE_EXCLUDES' "$DOTFILES_DIR/shell/completion.sh" || true)
assert_equals "0" "$carapace_in_completion" \
    "CARAPACE_EXCLUDES is not set in completion.sh, which runs after carapace init"

# The subshell-local HOME and CARAPACE_EXCLUDES are the point of these two
# checks -- exports.sh must be probed against a controlled environment, and the
# result must not leak back into the suite.
# shellcheck disable=SC2030
carapace_excludes=$(
    export HOME="$TMP/carapace_home"
    source "$DOTFILES_DIR/shell/exports.sh" 2>/dev/null
    printf '%s' "$CARAPACE_EXCLUDES"
)
assert_contains ",$carapace_excludes," ",wt," "sourcing exports.sh excludes the wt spec"

# Pre-existing exclusions are a deliberate user or devcontainer choice; assign
# instead of append and they silently come back.
# shellcheck disable=SC2031
carapace_excludes_kept=$(
    export HOME="$TMP/carapace_home"
    export CARAPACE_EXCLUDES="docker,kubectl"
    source "$DOTFILES_DIR/shell/exports.sh" 2>/dev/null
    source "$DOTFILES_DIR/shell/exports.sh" 2>/dev/null
    printf '%s' "$CARAPACE_EXCLUDES"
)
assert_equals "docker,kubectl,wt" "$carapace_excludes_kept" \
    "exports.sh appends wt to existing excludes and stays idempotent"

# Link five: with the dir on fpath, compinit must actually bind wt to _wt --
# guards the #compdef tag and the filename in the installed clone's
# completions/_wt, which bootstrap/completions.sh links into the zsh dir.
if command -v zsh >/dev/null 2>&1 && [[ -n "$WT_COMP_DIR" && -f "$WT_COMP_DIR/_wt" ]]; then
    comps_wt=$(zsh -f -c "
        mkdir -p '$TMP/zfpath'
        ln -sf '$WT_COMP_DIR/_wt' '$TMP/zfpath/_wt'
        fpath=('$TMP/zfpath' \$fpath)
        autoload -Uz compinit
        compinit -u -d '$TMP/zcompdump'
        print -r -- \${_comps[wt]}
    " 2>/dev/null)
    assert_equals "_wt" "$comps_wt" "compinit binds wt to _wt when the dir is on fpath"
else
    echo "  (zsh or the wt clone's completions missing -- skipping compinit binding check)"
fi

cd "$TMP" || exit 1

# ============================================================
# Summary
# ============================================================
print_test_summary
