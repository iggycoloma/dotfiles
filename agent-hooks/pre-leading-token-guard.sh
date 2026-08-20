#!/usr/bin/env bash
# Deny Bash commands that bury a sandbox-excluded tool behind another leading
# token. sandbox.excludedCommands matches on the command's first token only,
# so `cd dir && glab ...`, `for m in ...; do glab ...; done`, and
# `out=$(wt ...)` all run the tool sandboxed, where it dies on its denied
# config directory. Session telemetry showed ~50 such failures before this
# guard existed; prose rules in CLAUDE.md did not stop them.

# Containers are their own isolation boundary and run with sandbox.enabled
# false, so no command shape can die sandboxed there and a deny would cite a
# rationale that is untrue in that environment. bin/sync-settings.sh strips
# this hook from the container settings variant; this check (same sentinels
# as bootstrap/detect.sh) is defense-in-depth for a container the host
# variant reached anyway.
if [[ -n "${CODESPACES:-}" || -n "${REMOTE_CONTAINERS:-}" || -f /.dockerenv ]]; then
    exit 0
fi

if ! command -v jq &>/dev/null; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"jq is required for the leading-token guard"}}'
    exit 0
fi

input=$(cat)
[[ "$(printf '%s' "$input" | jq -r '.tool_name // empty')" == "Bash" ]] || exit 0
command_text=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[[ -n "$command_text" ]] || exit 0

# Must mirror sandbox.excludedCommands in claude-code/settings.json
# (single-token entries; `git worktree` and `git checkout` are handled by the
# leading `git` never being sandbox-fatal in the same way).
# tests/test-consistency.sh asserts the mirror, so drift fails the suite.
TOOLS='glab|gh|wt|docker|devcontainer'

# Leading token is an excluded tool: the whole invocation runs unsandboxed.
if printf '%s' "$command_text" | grep -qE "^[[:space:]]*($TOOLS)([[:space:]]|$)"; then
    exit 0
fi

# Excluded tool at a later command position: after && || ; | ( $( backtick,
# or as a loop/conditional body via do/then. Quoted matches (rg patterns,
# echo strings) can false-positive; the cost is one rewrite with a clear
# reason, versus a silent sandboxed death and a confused retry loop.
if printf '%s' "$command_text" | grep -qE "(&&|\|\||[;|(\`]|\\\$\(|^[[:space:]]*(do|then)[[:space:]]|[[:space:]](do|then)[[:space:]])[[:space:]]*(command[[:space:]]+|env[[:space:]]+)?($TOOLS)([[:space:]]|$)"; then
    jq -n -c '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
        permissionDecisionReason: "A sandbox-excluded tool (glab, gh, wt, docker, devcontainer) is not the leading token of this command, so it would run sandboxed and fail on its denied config directory. Make it the first token: run cd in its own Bash call or use --repo/-R, extract fields with -F json --jq instead of capturing into variables, and repeat explicit invocations instead of loops."}}'
    exit 0
fi

exit 0
