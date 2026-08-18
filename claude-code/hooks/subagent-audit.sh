#!/usr/bin/env bash
# SubagentStart / SubagentStop hook -- one JSONL line per subagent event.
#
# Sessions that fan out agent fleets otherwise leave no per-agent trace; this
# gives the operator a joinable log (by agent_id) of what ran, under which
# session, and for how long. Duration is computed at stop by looking up the
# matching start line's epoch.
#
# Log: ~/.local/state/claude-code/agent-audit.jsonl
# Observability only: always exits 0 and never blocks the agent lifecycle.

command -v jq &>/dev/null || exit 0

input=$(cat)

EVENT=$(echo "$input" | jq -r '.hook_event_name // empty')
case "$EVENT" in
    SubagentStart|SubagentStop) ;;
    *) exit 0 ;;
esac

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0
LOG_FILE="$LOG_DIR/agent-audit.jsonl"

AGENT_ID=$(echo "$input" | jq -r '.agent_id // empty')
now_epoch=$(date +%s)

duration=null
if [[ "$EVENT" == "SubagentStop" && -n "$AGENT_ID" && -f "$LOG_FILE" ]]; then
    # tail bounds the scan on a long-lived log; the start line is recent.
    start_epoch=$(tail -500 "$LOG_FILE" | jq -r --arg id "$AGENT_ID" \
        'select(.event == "SubagentStart" and .agent_id == $id) | .epoch' \
        2>/dev/null | tail -1)
    if [[ "$start_epoch" =~ ^[0-9]+$ ]]; then
        duration=$((now_epoch - start_epoch))
    fi
fi

echo "$input" | jq -c --arg ts "$(date -Is)" --argjson epoch "$now_epoch" \
    --argjson duration "$duration" '{
        ts: $ts,
        epoch: $epoch,
        event: .hook_event_name,
        session_id: (.session_id // null),
        agent_id: (.agent_id // null),
        agent_type: (.agent_type // null),
        cwd: (.cwd // null),
        duration_s: $duration
    }' >> "$LOG_FILE" 2>/dev/null

exit 0
