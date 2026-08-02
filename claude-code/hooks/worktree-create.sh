#!/usr/bin/env bash
# WorktreeCreate shim: route Claude Code worktree creation through wt so
# worktrees land in the orchestration/clone layout with provisioning,
# runtime identity, and relative paths (see bin/wt).
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
wt_bin="${WT_BIN:-$HOME/.local/bin/dotfiles-bin/wt}"

fallback_add() {
    local dest="${base_path:-$cwd/.claude/worktrees}/$name"
    mkdir -p "$(dirname "$dest")" 2>/dev/null || true
    if git -C "$cwd" worktree add --relative-paths -b "worktree-$name" "$dest" 1>&2; then
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
