#!/usr/bin/env bash
# Record session lifecycle metadata without reading transcripts.

command -v jq &>/dev/null || exit 0
input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')
case "$event" in SessionStart|SessionEnd) ;; *) exit 0 ;; esac
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/agent-hooks"
mkdir -p "$log_dir" 2>/dev/null || exit 0
printf '%s' "$input" | jq -c --arg ts "$(date -Is)" '
    {ts:$ts,event:.hook_event_name,harness:(if has("model") then "codex" else "claude" end),
     session_id:(.session_id // null),project:((.cwd // "unknown") | split("/")[-1]),
     source:(.source // null),reason:(.reason // null),model:(.model // null)}' \
    >> "$log_dir/sessions.jsonl" 2>/dev/null

