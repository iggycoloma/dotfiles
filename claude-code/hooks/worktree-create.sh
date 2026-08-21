#!/usr/bin/env bash
# WorktreeCreate shim: route Claude Code worktree creation through wt so
# worktrees land in the orchestration/clone layout with provisioning,
# runtime identity, and relative paths (see wt, from worktree-orchestrator).
#
# Failure policy: degrade, never break. If wt is missing or unsuitable,
# fall back to plain `git worktree add --relative-paths` at Claude's
# suggested location. Exit non-zero ONLY when wt's ignore-validation
# rejects provisioning -- aborting creation is the correct outcome for a
# security failure, and for nothing else.
set -uo pipefail

input="$(cat)"
json_field() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }

base_path="$(json_field '.worktree_base_path')"
suffix="$(json_field '.worktree_suffix')"
cwd="$(json_field '.cwd')"

[[ -n "$cwd" && -d "$cwd" ]] || cwd="$PWD"
name="${suffix:-claude-$$}"
wt_bin="${WT_BIN:-$HOME/.local/bin/wt}"

fallback_add() {
    local dest="${base_path:-$cwd/.claude/worktrees}/$name"
    mkdir -p "$(dirname "$dest")" 2>/dev/null || true
    # --relative-paths needs git >= min_git; older git errors on the flag.
    # Canonical floor: bootstrap/versions.sh (DOTFILES_MIN_GIT); inlined
    # because this hook deploys standalone. tests/test-consistency.sh keeps
    # the copies in sync.
    local rel="" min_git="2.48.0"
    if [[ "$(printf '%s\n%s\n' "$(git --version | awk '{print $3}')" "$min_git" | sort -V | head -1)" == "$min_git" ]]; then
        rel="--relative-paths"
    fi
    # A branch left over from an earlier worktree (removed without
    # deleting its branch) must not abort creation; uniquify instead.
    local branch="worktree-$name"
    if git -C "$cwd" show-ref --verify --quiet "refs/heads/$branch"; then
        branch="$branch-$$"
    fi
    # shellcheck disable=SC2086  # rel is deliberately word-split
    if git -C "$cwd" worktree add $rel -b "$branch" "$dest" 1>&2; then
        printf '%s\n' "$dest"
        exit 0
    fi
    echo "worktree-create: fallback git worktree add failed" >&2
    exit 1
}

if [[ -x "$wt_bin" ]]; then
    # Reuse: if the name already resolves to a worktree, return it.
    if existing="$(cd "$cwd" && "$wt_bin" path "$name" 2>/dev/null)" && [[ -d "$existing" ]]; then
        printf '%s\n' "$existing"
        exit 0
    fi

    out="$(mktemp)" err="$(mktemp)"
    trap 'rm -f "$out" "$err"' EXIT
    if (cd "$cwd" && "$wt_bin" add "$name") >"$out" 2>"$err"; then
        cat "$err" >&2
        path="$(tail -1 "$out")"
        if [[ -d "$path" ]]; then
            printf '%s\n' "$path"
            exit 0
        fi
    else
        cat "$err" >&2
        # The one intentional abort: provisioning security validation.
        if grep -q 'refusing to provision\|provisioning failed' "$err"; then
            exit 1
        fi
    fi
fi

fallback_add
