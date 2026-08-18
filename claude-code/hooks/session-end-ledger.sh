#!/usr/bin/env bash
# SessionEnd hook -- append a per-session usage row to a CSV ledger.
#
# The SessionEnd payload carries no cost or token figures, only
# transcript_path, so totals are summed from the transcript JSONL: token
# counts from each assistant message's .message.usage, cost from per-entry
# .costUSD when present (older transcripts; newer ones may omit it, leaving
# the column empty). Duration comes from the first and last entry timestamps.
#
# Ledger: ~/.local/state/claude-code/session-ledger.csv
# Observability only: always exits 0 and never blocks session shutdown.

command -v jq &>/dev/null || exit 0

input=$(cat)

SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
TRANSCRIPT=$(echo "$input" | jq -r '.transcript_path // empty')
CWD=$(echo "$input" | jq -r '.cwd // empty')
[[ -f "$TRANSCRIPT" ]] || exit 0

# The parser is Claude-specific but the log root is not: everything the hook
# layer records lives under one agent-hooks state dir so the observability
# story stays greppable in one place.
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/agent-hooks"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0
LEDGER="$LOG_DIR/session-ledger.csv"

# One pass over the transcript. fromjson? skips malformed lines; timestamps
# drop fractional seconds because jq's fromdate cannot parse them.
row=$(jq -R -r -n '
    [inputs | fromjson? | select(type == "object")] as $e
    | [$e[].timestamp // empty
       | sub("\\.[0-9]+(?<z>Z?)$"; .z) | try fromdate catch empty] as $t
    | [$e[].message.usage? // empty | select(type == "object")] as $u
    | {
        duration_s: (if ($t | length) > 1 then (($t | max) - ($t | min)) else 0 end),
        input_tokens: ([$u[].input_tokens // 0] | add // 0),
        output_tokens: ([$u[].output_tokens // 0] | add // 0),
        cache_read_tokens: ([$u[].cache_read_input_tokens // 0] | add // 0),
        cache_creation_tokens: ([$u[].cache_creation_input_tokens // 0] | add // 0),
        cost_usd: ([$e[].costUSD? // empty] | if length > 0 then (add | tostring) else "" end)
      }
    | [.duration_s, .input_tokens, .output_tokens,
       .cache_read_tokens, .cache_creation_tokens, .cost_usd]
    | @json
' < "$TRANSCRIPT" 2>/dev/null) || exit 0
[[ -n "$row" ]] || exit 0

if [[ ! -f "$LEDGER" ]]; then
    echo 'ended_at,session_id,project,duration_s,input_tokens,output_tokens,cache_read_tokens,cache_creation_tokens,cost_usd' > "$LEDGER"
fi

metrics=$(printf '%s' "$row" | jq -c '.') || exit 0
jq -nr --arg ended "$(date -Is)" --arg session "$SESSION_ID" \
    --arg project "$(basename "${CWD:-unknown}")" --argjson metrics "$metrics" \
    '[$ended,$session,$project] + $metrics | @csv' >> "$LEDGER"
exit 0
