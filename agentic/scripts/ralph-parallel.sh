#!/usr/bin/env bash
set -euo pipefail

# ralph-parallel.sh -- Launch multiple Ralph loops on separate worktrees.
# Usage: ralph-parallel.sh [options] branch1:prd1.md branch2:prd2.md ...

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RALPH_SCRIPT="$SCRIPT_DIR/ralph.sh"

# Resolve logging.sh (same cascade as ralph.sh).
LOGGING_SH=""
if [[ -f "$SCRIPT_DIR/../../bootstrap/logging.sh" ]]; then
    DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
    LOGGING_SH="$DOTFILES_DIR/bootstrap/logging.sh"
elif [[ -f "$SCRIPT_DIR/../lib/logging.sh" ]]; then
    LOGGING_SH="$SCRIPT_DIR/../lib/logging.sh"
elif [[ -f "${DOTFILES_DIR:-}/bootstrap/logging.sh" ]]; then
    LOGGING_SH="$DOTFILES_DIR/bootstrap/logging.sh"
else
    echo "Error: cannot locate logging.sh (expected repo bootstrap/ or ~/.agentic/lib/)" >&2
    exit 1
fi

# shellcheck source=../../bootstrap/logging.sh
source "$LOGGING_SH"

# --- Defaults ---

PROMPT_FILE=""
MAX_ITERATIONS=20
PERMISSION_MODE="acceptEdits"
NOTIFY=true
SPECS=()

# Max-subscription mode: skip budget cap, default to sonnet
if [[ "${RALPH_MAX_MODE:-0}" == "1" ]]; then
    MAX_BUDGET=""
    MODEL="${RALPH_DEFAULT_MODEL:-sonnet}"
else
    MAX_BUDGET="${RALPH_DEFAULT_BUDGET:-10}"
    MODEL="${RALPH_DEFAULT_MODEL:-}"
fi

# --- Help ---

show_help() {
    cat <<'HELP'
Usage: ralph-parallel.sh [options] spec1 spec2 ...

Launch multiple Ralph loops on separate worktrees in parallel.
Each spec is branch:prd-file (e.g., feat/auth:auth-prd.md).

Options:
  --prompt-file <path>         Shared prompt template (required)
  --max-iterations <N>         Max iterations per loop (default: 20)
  --max-budget-usd <N>         Cost cap per iteration per loop (default: 10)
  --permission-mode <mode>     Claude permission mode (default: acceptEdits)
  --model <model>              Model override
  --no-notify                  Disable Pushover notifications
  -h, --help                   Show this help

Examples:
  ralph-parallel.sh --prompt-file PROMPT.md feat/auth:auth-prd.md feat/api:api-prd.md
  ralph-parallel.sh --prompt-file PROMPT.md --max-iterations 10 fix/bug1:bug1.md fix/bug2:bug2.md
HELP
}

# --- Argument parsing ---

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prompt-file)
                PROMPT_FILE="${2:?--prompt-file requires a value}"
                shift 2
                ;;
            --max-iterations)
                MAX_ITERATIONS="${2:?--max-iterations requires a value}"
                shift 2
                ;;
            --max-budget-usd)
                MAX_BUDGET="${2:?--max-budget-usd requires a value}"
                shift 2
                ;;
            --permission-mode)
                PERMISSION_MODE="${2:?--permission-mode requires a value}"
                shift 2
                ;;
            --model)
                MODEL="${2:?--model requires a value}"
                shift 2
                ;;
            --no-notify)
                NOTIFY=false
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                return 1
                ;;
            *)
                SPECS+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$PROMPT_FILE" ]]; then
        log_error "Missing required option: --prompt-file"
        show_help
        return 1
    fi

    if [[ ! -f "$PROMPT_FILE" ]]; then
        log_error "Prompt file not found: $PROMPT_FILE"
        return 1
    fi

    if [[ ${#SPECS[@]} -eq 0 ]]; then
        log_error "No specs provided. Each spec should be branch:prd-file"
        show_help
        return 1
    fi

    # Validate spec format
    for spec in "${SPECS[@]}"; do
        if [[ ! "$spec" =~ : ]]; then
            log_error "Invalid spec format: $spec (expected branch:prd-file)"
            return 1
        fi
        local prd="${spec#*:}"
        if [[ ! -f "$prd" ]]; then
            log_error "PRD file not found: $prd (from spec: $spec)"
            return 1
        fi
    done
}

# --- Notification ---

# Returns 0 if the file is owner-readable only (mode 0600/0400/0200/0000).
creds_file_secure() {
    local f="$1" mode=""
    if mode=$(stat -c '%a' "$f" 2>/dev/null); then
        :
    elif mode=$(stat -f '%Lp' "$f" 2>/dev/null); then
        :
    else
        return 1
    fi
    case "$mode" in
        600|400|200|000) return 0 ;;
        *) return 1 ;;
    esac
}

parallel_notify() {
    local message="$1"
    [[ "$NOTIFY" != true ]] && return 0

    local creds_file="$HOME/.claude/hooks/.pushover-creds"
    local app_token="${PUSHOVER_APP_TOKEN_CLAUDE:-${PUSHOVER_TOKEN:-}}"
    local user="${PUSHOVER_USER:-}"

    if [[ -z "$app_token" || -z "$user" ]] && [[ -f "$creds_file" ]]; then
        if ! creds_file_secure "$creds_file"; then
            log_warn "Skipping $creds_file: file is group- or world-readable."
        else
            [[ -z "$app_token" ]] && app_token=$(sed -n '1p' "$creds_file")
            [[ -z "$user" ]] && user=$(sed -n '2p' "$creds_file")
        fi
    fi

    [[ -z "$app_token" || -z "$user" ]] && return 0

    curl -s \
        -F "token=$app_token" \
        -F "user=$user" \
        -F "title=Ralph Parallel" \
        -F "message=$message" \
        -F "priority=1" \
        -F "sound=cosmic" \
        https://api.pushover.net/1/messages.json &>/dev/null &
}

# --- Main ---

main() {
    parse_args "$@"

    local start_time
    start_time=$(date +%s)
    local total=${#SPECS[@]}

    log_section "Ralph Parallel: $total loops"

    local results_dir
    results_dir=$(mktemp -d)
    local -a pids=()
    local -a branches=()

    # Launch each Ralph loop
    for spec in "${SPECS[@]}"; do
        local branch="${spec%%:*}"
        local prd="${spec#*:}"
        branches+=("$branch")

        log_info "Starting: $branch (PRD: $prd)"

        local -a ralph_args=(
            --prompt-file "$PROMPT_FILE"
            --prd "$prd"
            --max-iterations "$MAX_ITERATIONS"
            --permission-mode "$PERMISSION_MODE"
            --worktree "$branch"
            --no-notify  # suppress per-loop notifications; we send aggregate
        )
        [[ -n "$MAX_BUDGET" ]] && ralph_args+=(--max-budget-usd "$MAX_BUDGET")
        [[ -n "$MODEL" ]] && ralph_args+=(--model "$MODEL")

        "$RALPH_SCRIPT" "${ralph_args[@]}" \
            > "${results_dir}/${branch//\//_}.log" 2>&1 &
        pids+=($!)
    done

    log_info "$total loops running. Waiting for completion..."

    # Wait for all, collect results
    local failures=0
    local successes=0
    for i in "${!pids[@]}"; do
        local pid="${pids[$i]}"
        local branch="${branches[$i]}"
        if wait "$pid"; then
            log_success "$branch: completed"
            successes=$((successes + 1))
        else
            local rc=$?
            log_error "$branch: failed (exit $rc)"
            failures=$((failures + 1))
        fi
    done

    local elapsed=$(( $(date +%s) - start_time ))

    # Summary
    log_section "Results"
    log_info "$successes/$total succeeded, $failures/$total failed (${elapsed}s)"

    # Aggregate notification
    parallel_notify "$successes/$total completed, $failures failed (${elapsed}s)"

    # Clean up
    rm -rf "$results_dir"

    [[ $failures -gt 0 ]] && return 1
    return 0
}

# Allow sourcing for testing without executing main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
