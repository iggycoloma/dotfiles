#!/usr/bin/env bash
# Record start/stop metadata for Claude Code and Codex subagents.

command -v jq &>/dev/null || exit 0
input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')
case "$event" in SubagentStart|SubagentStop) ;; *) exit 0 ;; esac
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/agent-hooks"
mkdir -p "$log_dir" 2>/dev/null || exit 0
log_file="$log_dir/subagents.jsonl"
agent_id=$(printf '%s' "$input" | jq -r '.agent_id // empty')
now_epoch=$(date +%s)
duration=null
if [[ "$event" == "SubagentStop" && -n "$agent_id" && -f "$log_file" ]]; then
    start_epoch=$(tail -500 "$log_file" | jq -r --arg id "$agent_id" --arg session "$(printf '%s' "$input" | jq -r '.session_id // empty')" \
        'select(.event == "SubagentStart" and .agent_id == $id and .session_id == $session) | .epoch' 2>/dev/null | tail -1)
    [[ "$start_epoch" =~ ^[0-9]+$ ]] && duration=$((now_epoch - start_epoch))
fi
printf '%s' "$input" | jq -c --arg ts "$(date -Is)" --argjson epoch "$now_epoch" --argjson duration "$duration" '
    {ts:$ts,epoch:$epoch,event:.hook_event_name,harness:(if has("turn_id") then "codex" else "claude" end),
     session_id:(.session_id // null),agent_id:(.agent_id // null),agent_type:(.agent_type // null),
     project:((.cwd // "unknown") | split("/")[-1]),duration_s:$duration}' >> "$log_file" 2>/dev/null

