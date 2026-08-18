#!/usr/bin/env bash
# ConfigChange hook -- block config changes from taking effect mid-session.
#
# An agent that can edit settings or skills mid-session can widen its own
# permissions as a step toward something the rules forbid. Blocking here does
# not prevent the file write -- it prevents the changed config from being
# reloaded into the live session, so edits apply on the next session start,
# after a human can review them. policy_settings cannot be blocked and is
# excluded by the settings.json matcher.
#
# Escape hatch for sanctioned flows (e.g. the update-config skill acting on
# an explicit user request): DOTFILES_ALLOW_CONFIG_RELOAD=1.

if [[ "${DOTFILES_ALLOW_CONFIG_RELOAD:-0}" == "1" ]]; then
    exit 0
fi

source_kind="unknown"
config_path=""
if command -v jq &>/dev/null; then
    input=$(cat)
    source_kind=$(echo "$input" | jq -r '.source // "unknown"')
    config_path=$(echo "$input" | jq -r '.file_path // empty')
fi

printf 'Blocked a mid-session %s reload (%s); inspect the ConfigChange debug log for this silent guard.\n' \
    "$source_kind" "${config_path:-unknown path}" >&2
exit 2
