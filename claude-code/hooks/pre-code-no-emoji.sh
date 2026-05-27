#!/usr/bin/env bash
# Claude wrapper for the shared no-emoji guard.

set -euo pipefail

HOOK_NAME="$(basename "$0")"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${DOTFILES_AGENT_HOOKS_DIR:-}" && -x "$DOTFILES_AGENT_HOOKS_DIR/$HOOK_NAME" ]]; then
    exec "$DOTFILES_AGENT_HOOKS_DIR/$HOOK_NAME"
elif [[ -x "$HOOK_DIR/../../agent-hooks/$HOOK_NAME" ]]; then
    exec "$HOOK_DIR/../../agent-hooks/$HOOK_NAME"
elif [[ -x "$HOME/.agent-hooks/$HOOK_NAME" ]]; then
    exec "$HOME/.agent-hooks/$HOOK_NAME"
fi

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Missing shared agent hook: %s"}}\n' "$HOOK_NAME"
exit 0
