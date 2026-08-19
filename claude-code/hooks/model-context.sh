#!/usr/bin/env bash
# SessionStart hook - inject model-specific instruction fragments.
#
# SessionStart is the only hook event whose input carries the session's model
# id (optional `model` field). Print the matching fragment from
# ~/.claude/model-adjustments/ so corrections for one model's known biases
# never load into sessions running a different model. Matching strips the
# `claude-` prefix, then drops trailing `-` components until a file matches:
# claude-opus-5-20260101 -> opus-5-20260101.md -> opus-5.md -> opus.md.
# Fails open: no model field, no jq, or no matching fragment means no output.
# A /model switch mid-session is invisible to hooks; the fragment loaded at
# start stays in effect.

set -euo pipefail

fragment_dir="$HOME/.claude/model-adjustments"

command -v jq >/dev/null 2>&1 || exit 0
[[ -d "$fragment_dir" ]] || exit 0

model="$(jq -r '.model // empty' 2>/dev/null || true)"
[[ -n "$model" ]] || exit 0

key="${model#claude-}"
while [[ -n "$key" ]]; do
    if [[ -f "$fragment_dir/$key.md" ]]; then
        cat "$fragment_dir/$key.md"
        exit 0
    fi
    [[ "$key" == *-* ]] || break
    key="${key%-*}"
done

exit 0
