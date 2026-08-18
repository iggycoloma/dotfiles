#!/usr/bin/env bash
# Record session lifecycle metadata without reading transcripts.
#
# The harness comes from $1, set by each harness's own wiring (settings.json
# passes "claude", codex/hooks.json passes "codex"). Sniffing payload fields
# was wrong-way-brittle: Claude's SessionStart can carry a model field too,
# so has("model") intermittently misclassified Claude sessions as codex.

harness="${1:-unknown}"
command -v jq &>/dev/null || exit 0
input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')
case "$event" in SessionStart|SessionEnd) ;; *) exit 0 ;; esac
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/agent-hooks"
mkdir -p "$log_dir" 2>/dev/null || exit 0
printf '%s' "$input" | jq -c --arg ts "$(date -Is)" --arg harness "$harness" '
    {ts:$ts,event:.hook_event_name,harness:$harness,
     session_id:(.session_id // null),project:((.cwd // "unknown") | split("/")[-1]),
     source:(.source // null),reason:(.reason // null),model:(.model // null)}' \
    >> "$log_dir/sessions.jsonl" 2>/dev/null

