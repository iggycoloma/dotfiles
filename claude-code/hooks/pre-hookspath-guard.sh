#!/usr/bin/env bash
# PreToolUse hook -- deny git config writes to core.hooksPath.
#
# Setting repo-local core.hooksPath silently disables the global gitleaks
# secret scan and commit-msg validation, so the Guardrails prohibition gets
# mechanical enforcement here. This is deliberately NOT a general Bash
# credential scan (see pre-security.sh for why those stay out): it is one
# narrow subcommand where the git CLI is essentially the only write path,
# the false-positive cost is near zero, and a miss is a silent bypass of
# secret scanning. Obfuscated commands still evade it; the command-legibility
# rule forbids those, so this catches the honest-but-forgetful path.
#
# Reads (--get*, --list, list, get) and unsets (--unset*, unset) pass:
# unsetting a repo-local override restores the global hooks, which is the
# fix action, not the hazard.

# Fail closed like the other guards: a missing jq must produce an explicit
# deny rather than a silent pass.
if ! command -v jq &>/dev/null; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"jq is required for the hooksPath guard"}}'
    exit 0
fi

input=$(cat)

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
[[ "$TOOL_NAME" != "Bash" ]] && exit 0

COMMAND=$(echo "$input" | jq -r '.tool_input.command // empty')
[[ -z "$COMMAND" ]] && exit 0

# git config keys are case-insensitive, so match hookspath case-insensitively.
# git must sit at a command position (string start or after ; & | ( or a
# newline), so prose in a quoted argument -- a commit message discussing the
# setting -- does not trip the guard. Quoting tricks can still hide a real
# invocation; this is a tripwire on the honest path, not a boundary.
if ! echo "$COMMAND" | grep -qiE '(^|[;&|(])[[:space:]]*(command[[:space:]]+|env[[:space:]]+)?git([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+config([[:space:]]|$)' \
    || ! echo "$COMMAND" | grep -qi 'hookspath'; then
    exit 0
fi

# Read-only and unset forms pass; everything else touching hooksPath is a write.
if echo "$COMMAND" | grep -qiE -- '--get(-all|-regexp)?([[:space:]]|$)|--list([[:space:]]|$)|config[[:space:]]+(list|get|unset)([[:space:]]|$)|--unset(-all)?([[:space:]]|$)'; then
    exit 0
fi

jq -n -c '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
    permissionDecisionReason: "Setting core.hooksPath is blocked: a repo-local hooks path silently disables the global gitleaks secret scan and commit-msg validation. Unset an existing override with git config --unset core.hooksPath if needed."}}'
exit 0
