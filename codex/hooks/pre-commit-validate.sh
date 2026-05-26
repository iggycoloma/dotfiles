#!/usr/bin/env bash
# Codex wrapper for the shared commit-message guard.

set -euo pipefail

HOOK_NAME="$(basename "$0")"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_HOOK_ASK_DECISION=deny

run_hook() {
    local hook_path="$1"
    local output

    set +e
    output="$("$hook_path")"
    local status=$?
    set -e

    if [[ $status -ne 0 ]]; then
        if [[ -n "$output" ]]; then
            printf '%s\n' "$output"
        else
            printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Shared agent hook failed: %s"}}\n' "$HOOK_NAME"
        fi
        exit 0
    fi

    if echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null 2>&1; then
        echo "$output" | jq -c '.hookSpecificOutput.permissionDecision = "deny"'
    else
        printf '%s\n' "$output"
    fi
    exit 0
}

if [[ -n "${DOTFILES_AGENT_HOOKS_DIR:-}" && -x "$DOTFILES_AGENT_HOOKS_DIR/$HOOK_NAME" ]]; then
    run_hook "$DOTFILES_AGENT_HOOKS_DIR/$HOOK_NAME"
elif [[ -x "$HOOK_DIR/../../agent-hooks/$HOOK_NAME" ]]; then
    run_hook "$HOOK_DIR/../../agent-hooks/$HOOK_NAME"
elif [[ -x "$HOME/.agent-hooks/$HOOK_NAME" ]]; then
    run_hook "$HOME/.agent-hooks/$HOOK_NAME"
fi

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Missing shared agent hook: %s"}}\n' "$HOOK_NAME"
exit 0
