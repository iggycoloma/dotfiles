#!/usr/bin/env bash
# sync-settings.sh -- Generate claude-code/settings.container.json from settings.json.
#
# The two files differ in exactly one key: `.sandbox`. Hosts run the bwrap /
# Seatbelt sandbox; containers are their own boundary and set
# `sandbox.enabled: false` with nothing else under the key (docs/sandbox.md).
# Every other key -- permissions, hooks, statusLine, attribution -- is identical
# by design.
#
# Generating the container variant rather than hand-maintaining it makes the
# "added a permission to one file and forgot the other" bug impossible instead
# of merely detectable. bin/settings-drift.sh remains the verifier, and also
# covers the Codex TOML pair, which is not derivable this way: those variants
# differ by *value* (workspace-write vs danger-full-access) and carry comments
# that a yq round-trip would strip.
#
# Exit codes:
#   0  container variant written, or already current under --check
#   1  --check and the committed container variant is stale
#   2  prerequisite missing or host variant unreadable

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# shellcheck source=../bootstrap/logging.sh
source "$DOTFILES_DIR/bootstrap/logging.sh"

CHECK_ONLY=false

# The entire container-tier sandbox policy. Containers are the isolation
# boundary themselves, so nothing else belongs under this key -- see
# docs/sandbox.md "Local devcontainers".
CONTAINER_SANDBOX='{"enabled": false}'

# CLAUDE_CODE_SUBPROCESS_ENV_SCRUB must NOT reach the container variant. Setting
# it makes Claude Code "ignore `filesystem.disabled` from every source,
# including managed settings, and keep filesystem isolation on"
# (https://code.claude.com/docs/en/sandboxing#which-settings-can-disable-it).
# In a devcontainer that forces the bwrap machinery on even though
# sandbox.enabled is false, and bwrap cannot create user namespaces there, so
# every Bash command dies at startup. Hosts keep it; containers get env scrubbed.
CONTAINER_ENV_STRIP='CLAUDE_CODE_SUBPROCESS_ENV_SCRUB'

usage() {
    cat <<'HELP'
Usage: sync-settings.sh [options]

Regenerate claude-code/settings.container.json from claude-code/settings.json,
replacing the .sandbox block with the container-tier policy.

Options:
  --check     Do not write; exit 1 if the committed file is stale
  -h, --help  Show this help

Exit code:
  0  written, or already current under --check
  1  --check and the committed file is stale
  2  prerequisite missing or host variant unreadable
HELP
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check) CHECK_ONLY=true; shift ;;
            -h|--help) usage; exit 0 ;;
            *) log_error "Unknown option: $1"; usage; return 1 ;;
        esac
    done
}

main() {
    parse_args "$@"

    command -v jq >/dev/null 2>&1 || log_and_return error 2 "jq is required"

    local host="$DOTFILES_DIR/claude-code/settings.json"
    local container="$DOTFILES_DIR/claude-code/settings.container.json"

    [[ -f "$host" ]] || log_and_return error 2 "host variant missing: $host"

    local generated
    if ! generated=$(jq --argjson sandbox "$CONTAINER_SANDBOX" \
        --arg strip "$CONTAINER_ENV_STRIP" \
        '.sandbox = $sandbox
         | if has("env") then .env |= del(.[$strip]) else . end
         | if has("env") and (.env | length) == 0 then del(.env) else . end' \
        "$host" 2>&1); then
        log_and_return error 2 "host variant is not valid JSON: $generated"
        return 2
    fi

    if [[ "$CHECK_ONLY" == true ]]; then
        if [[ -f "$container" ]] && diff -q <(printf '%s\n' "$generated") "$container" >/dev/null 2>&1; then
            log_success "settings.container.json is current"
            return 0
        fi
        log_error "settings.container.json is stale -- run 'make sync-settings'"
        if [[ -f "$container" ]]; then
            diff <(printf '%s\n' "$generated") "$container" | sed 's/^/    /' || true
        fi
        return 1
    fi

    printf '%s\n' "$generated" > "$container"
    log_success "Generated claude-code/settings.container.json from settings.json"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
