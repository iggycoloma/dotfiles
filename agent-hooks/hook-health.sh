#!/usr/bin/env bash
# Surface missing shared-hook prerequisites at session start.

missing=""
for dependency in bash jq git; do
    command -v "$dependency" &>/dev/null || missing="$missing $dependency"
done
for hook in pre-security.sh pre-code-no-emoji.sh pre-hookspath-guard.sh pre-leading-token-guard.sh post-scope-audit.sh post-dep-audit.sh tool-telemetry.sh subagent-audit.sh session-audit.sh; do
    [[ -x "${AGENT_HOOKS_DIR:-$HOME/.agent-hooks}/$hook" ]] || missing="$missing $hook"
done
[[ -z "$missing" ]] && exit 0
printf 'Hook health warning; missing or non-executable:%s\n' "$missing"

