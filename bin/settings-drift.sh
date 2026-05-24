#!/usr/bin/env bash
# settings-drift.sh -- Verify host vs container settings variants stay in sync.
#
# The three-tier sandbox posture (docs/sandbox.md) ships two settings files
# per agentic CLI:
#   - claude-code/settings.json          (host: sandbox.enabled=true)
#   - claude-code/settings.container.json (container: sandbox.enabled=false)
#   - codex/config.toml                  (host: sandbox_mode=workspace-write)
#   - codex/config.container.toml        (container: sandbox_mode=danger-full-access)
#
# The sandbox block is intentionally different per tier; everything else
# (permissions, hooks, statusLine, approval_policy, etc.) MUST stay in sync.
# Adding a permission to settings.json and forgetting settings.container.json
# is a real bug we want to catch at lint time.
#
# Exit codes:
#   0  in sync (or files missing -- warned, not failed)
#   1  drift detected on at least one variant pair

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# shellcheck source=../bootstrap/logging.sh
source "$DOTFILES_DIR/bootstrap/logging.sh"

QUIET=false
JSON_OUTPUT=false
ERRORS=0

usage() {
    cat <<'HELP'
Usage: settings-drift.sh [options]

Compare host vs container settings variants for Claude Code and Codex.
Reports drift on every key outside the per-tier sandbox block.

Options:
  --quiet   Suppress per-file success lines; only report drift
  --json    Emit findings as JSONL (one object per drift)
  -h, --help  Show this help

Exit code:
  0  variants in sync
  1  drift detected
HELP
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quiet) QUIET=true; shift ;;
            --json)  JSON_OUTPUT=true; shift ;;
            -h|--help) usage; exit 0 ;;
            *) log_error "Unknown option: $1"; usage; return 1 ;;
        esac
    done
}

# Report a drift finding. In JSON mode, emit JSONL; otherwise human-readable.
emit_drift() {
    local pair="$1" exclude_key="$2" diff_output="$3"
    ERRORS=$((ERRORS + 1))
    if [[ "$JSON_OUTPUT" == true ]]; then
        jq -cn \
            --arg pair "$pair" \
            --arg exclude "$exclude_key" \
            --arg diff "$diff_output" \
            '{pair: $pair, excludeKey: $exclude, status: "drift", diff: $diff}'
    else
        log_error "$pair: drift detected (excluding $exclude_key)"
        printf '%s\n' "$diff_output" | sed 's/^/    /'
    fi
}

emit_ok() {
    local pair="$1" exclude_key="$2"
    if [[ "$JSON_OUTPUT" == true ]]; then
        jq -cn \
            --arg pair "$pair" \
            --arg exclude "$exclude_key" \
            '{pair: $pair, excludeKey: $exclude, status: "ok"}'
    elif [[ "$QUIET" != true ]]; then
        log_success "$pair: in sync (excluding $exclude_key)"
    fi
}

emit_skip() {
    local pair="$1" reason="$2"
    if [[ "$JSON_OUTPUT" == true ]]; then
        jq -cn \
            --arg pair "$pair" \
            --arg reason "$reason" \
            '{pair: $pair, status: "skipped", reason: $reason}'
    else
        log_warn "$pair: $reason"
    fi
}

# Compare two JSON files after deleting an excluded key path.
check_json_drift() {
    local pair="$1" host="$2" container="$3" exclude="$4"

    if [[ ! -f "$host" ]]; then
        emit_skip "$pair" "host variant missing: $host"
        return 0
    fi
    if [[ ! -f "$container" ]]; then
        emit_skip "$pair" "container variant missing: $container"
        return 0
    fi

    # -S canonicalizes key order. del(.path) removes the per-tier section.
    local h c diff_out
    if ! h=$(jq -S "del($exclude)" "$host" 2>&1); then
        emit_skip "$pair" "host variant not valid JSON: $h"
        return 0
    fi
    if ! c=$(jq -S "del($exclude)" "$container" 2>&1); then
        emit_skip "$pair" "container variant not valid JSON: $c"
        return 0
    fi

    if [[ "$h" == "$c" ]]; then
        emit_ok "$pair" "$exclude"
        return 0
    fi

    diff_out=$(diff <(printf '%s\n' "$h") <(printf '%s\n' "$c") || true)
    emit_drift "$pair" "$exclude" "$diff_out"
}

# Compare two TOML files after deleting an excluded key path.
# yq output is canonical for a given input, so we can string-compare.
check_toml_drift() {
    local pair="$1" host="$2" container="$3" exclude="$4"

    if [[ ! -f "$host" ]]; then
        emit_skip "$pair" "host variant missing: $host"
        return 0
    fi
    if [[ ! -f "$container" ]]; then
        emit_skip "$pair" "container variant missing: $container"
        return 0
    fi
    if ! command -v yq >/dev/null 2>&1; then
        emit_skip "$pair" "yq not installed; cannot diff TOML"
        return 0
    fi

    # Normalize: parse TOML -> emit JSON (canonical), drop the excluded key,
    # then compare. Using JSON as the intermediate makes the comparison
    # whitespace-insensitive and key-order-insensitive.
    local h c diff_out
    if ! h=$(yq -p toml -o json "del($exclude)" "$host" 2>&1 | jq -S '.'); then
        emit_skip "$pair" "host variant not valid TOML: $h"
        return 0
    fi
    if ! c=$(yq -p toml -o json "del($exclude)" "$container" 2>&1 | jq -S '.'); then
        emit_skip "$pair" "container variant not valid TOML: $c"
        return 0
    fi

    if [[ "$h" == "$c" ]]; then
        emit_ok "$pair" "$exclude"
        return 0
    fi

    diff_out=$(diff <(printf '%s\n' "$h") <(printf '%s\n' "$c") || true)
    emit_drift "$pair" "$exclude" "$diff_out"
}

main() {
    parse_args "$@"

    command -v jq >/dev/null 2>&1 || log_and_return error 2 "jq is required"

    if [[ "$JSON_OUTPUT" != true ]]; then
        log_section "settings-drift: comparing host vs container variants"
    fi

    check_json_drift \
        "claude-code" \
        "$DOTFILES_DIR/claude-code/settings.json" \
        "$DOTFILES_DIR/claude-code/settings.container.json" \
        ".sandbox"

    check_toml_drift \
        "codex" \
        "$DOTFILES_DIR/codex/config.toml" \
        "$DOTFILES_DIR/codex/config.container.toml" \
        ".sandbox_mode"

    if [[ "$JSON_OUTPUT" != true ]]; then
        if (( ERRORS > 0 )); then
            log_error "settings-drift: $ERRORS variant pair(s) drifted"
        else
            log_success "settings-drift: all variants in sync"
        fi
    fi

    (( ERRORS == 0 ))
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
