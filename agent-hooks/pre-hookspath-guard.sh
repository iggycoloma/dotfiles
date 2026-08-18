#!/usr/bin/env bash
# Block git config writes to core.hooksPath without trying to parse general Bash.

if ! command -v jq &>/dev/null; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"jq is required for the hooksPath guard"}}'
    exit 0
fi

input=$(cat)
[[ "$(printf '%s' "$input" | jq -r '.tool_name // empty')" == "Bash" ]] || exit 0
command_text=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[[ -n "$command_text" ]] || exit 0

if ! printf '%s' "$command_text" | grep -qiE '(^|[;&|(])[[:space:]]*(command[[:space:]]+|env[[:space:]]+)?git([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+config([[:space:]]|$)' \
    || ! printf '%s' "$command_text" | grep -qi 'hookspath'; then
    exit 0
fi

if printf '%s' "$command_text" | grep -qiE -- '--get(-all|-regexp)?([[:space:]]|$)|--list([[:space:]]|$)|config[[:space:]]+(list|get|unset)([[:space:]]|$)|--unset(-all)?([[:space:]]|$)'; then
    exit 0
fi

jq -n -c '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
    permissionDecisionReason: "Setting core.hooksPath is blocked because it disables the global secret-scanning and commit-message hooks. Unset an existing override with git config --unset core.hooksPath."}}'

