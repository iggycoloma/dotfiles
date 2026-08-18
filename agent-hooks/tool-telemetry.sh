#!/usr/bin/env bash
# Record metadata about shell-tool completion without persisting command/output text.
#
# The harness comes from $1, set by each harness's own wiring; see
# session-audit.sh for why payload sniffing was retired.

harness="${1:-unknown}"
command -v jq &>/dev/null || exit 0
input=$(cat)
[[ "$(printf '%s' "$input" | jq -r '.tool_name // empty')" == "Bash" ]] || exit 0
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/agent-hooks"
mkdir -p "$log_dir" 2>/dev/null || exit 0

printf '%s' "$input" | jq -c --arg ts "$(date -Is)" --arg harness "$harness" '
    def first_word:
        (.tool_input.command // "" | capture("^\\s*(?<x>[^[:space:];|&]+)").x? // "unknown")
        | if contains("=") then "env-assignment" else split("/")[-1] end;
    def exit_code:
        if .hook_event_name == "PostToolUseFailure" then
            ((.error // "") | capture("^Exit code (?<n>[0-9]+)").n? | tonumber?)
        else (.tool_response.exit_code? // .tool_response.exitCode? // null) end;
    {ts:$ts, event:"shell_tool_result", harness:$harness,
     session_id:(.session_id // null), project:((.cwd // "unknown") | split("/")[-1]),
     command:first_word, outcome:(if .hook_event_name == "PostToolUseFailure" then "failure" elif (exit_code // 0) != 0 then "failure" else "success" end),
     exit_code:exit_code, interrupted:(.is_interrupt // null), duration_ms:(.duration_ms // null)}
' >> "$log_dir/events.jsonl" 2>/dev/null
