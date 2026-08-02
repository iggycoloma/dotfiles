#!/usr/bin/env bash
# WorktreeRemove shim: route Claude Code worktree cleanup through wt so
# containers are torn down and allocated ports released (see bin/wt).
#
# Side-effect-only: cleanup must never block session shutdown, so this
# always exits 0. wt remove refuses dirty trees; a refused worktree stays
# on disk for the periodic sweep or a manual `wt remove`.
set -uo pipefail

input="$(cat)"
path="$(printf '%s' "$input" | jq -r '.worktree_path // empty' 2>/dev/null)"
[[ -n "$path" && -d "$path" ]] || exit 0

wt_bin="${WT_BIN:-$HOME/.local/bin/dotfiles-bin/wt}"
name="$(basename "$path")"

# Run from the project root (dirname of the shared git dir) rather than
# from inside the worktree being removed, which git refuses.
common="$(git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
root="$(dirname "$common")"
[[ -n "$common" && -d "$root" ]] || exit 0

if [[ -x "$wt_bin" ]]; then
    (cd "$root" && "$wt_bin" remove "$name") 1>&2 && exit 0
fi

# Fallback: plain removal (no container/port bookkeeping to do if wt
# never managed this worktree). Failures are logged and ignored.
git -C "$root" worktree remove "$path" 1>&2 || true
git -C "$root" worktree prune 1>&2 || true
exit 0
