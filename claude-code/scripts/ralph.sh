#!/usr/bin/env bash
set -euo pipefail

# ralph.sh -- Autonomous Claude Code loop runner.
# Iterates Claude with a prompt file until tasks are complete or guardrails hit.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve DOTFILES_DIR: deployed (~/.claude/scripts/) or dev (claude-code/scripts/)
if [[ -f "$SCRIPT_DIR/../../bootstrap/logging.sh" ]]; then
    DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
elif [[ -f "${DOTFILES_DIR:-}/bootstrap/logging.sh" ]]; then
    : # DOTFILES_DIR already set
else
    echo "Error: cannot locate bootstrap/logging.sh" >&2
    exit 1
fi

# shellcheck source=../../bootstrap/logging.sh
source "$DOTFILES_DIR/bootstrap/logging.sh"

# --- Defaults ---

PROMPT_FILE=""
PRD_FILE=""
MAX_ITERATIONS=20
PROGRESS_FILE="./progress.txt"
PERMISSION_MODE="acceptEdits"
WORKTREE=""
BARE=false
NOTIFY=true

# Max-subscription mode: skip budget cap (rate-limit gated), default to sonnet
# Enable by setting RALPH_MAX_MODE=1
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
Usage: ralph.sh [options] --prompt-file <path>

Autonomous Claude Code loop runner. Iterates Claude with a prompt file
until tasks are complete or guardrails are hit.

Options:
  --prompt-file <path>         Path to iteration prompt template (required)
  --prd <path>                 Path to PRD file (copied to workdir)
  --max-iterations <N>         Max loop iterations (default: 20)
  --max-budget-usd <N>         Cost cap per Claude invocation (default: 10, unset on Max)
  --progress-file <path>       Progress tracking file (default: ./progress.txt)
  --permission-mode <mode>     Claude permission mode (default: acceptEdits)
  --worktree <branch>          Run in a git worktree
  --model <model>              Model override (e.g., sonnet, opus)
  --bare                       Use bare mode (skip hooks, LSP, plugins)
  --no-notify                  Disable Pushover notifications
  -h, --help                   Show this help

Environment:
  RALPH_MAX_MODE=1             Max subscription mode: skip budget cap, default
                               to sonnet. Override with --model or --max-budget-usd.
  RALPH_DEFAULT_MODEL          Default model when --model not passed
  RALPH_DEFAULT_BUDGET         Default budget when --max-budget-usd not passed

Guardrails:
  The loop stops when any of these conditions is met:
  - Claude writes "## COMPLETE" to the progress file
  - Max iterations reached
  - Claude exits with an error
  - Per-iteration budget exceeded (--max-budget-usd)

Examples:
  ralph.sh --prompt-file PROMPT.md
  ralph.sh --prompt-file PROMPT.md --prd PRD.md --max-iterations 10
  ralph.sh --prompt-file PROMPT.md --worktree feat/my-feature --model sonnet
HELP
}

# --- Dependency checks ---

check_dependencies() {
    if ! command -v claude &>/dev/null; then
        log_error "Missing required tool: claude"
        return 1
    fi
}

# --- Argument parsing ---

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prompt-file)
                PROMPT_FILE="${2:?--prompt-file requires a value}"
                shift 2
                ;;
            --prd)
                PRD_FILE="${2:?--prd requires a value}"
                shift 2
                ;;
            --max-iterations)
                MAX_ITERATIONS="${2:?--max-iterations requires a value}"
                if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
                    log_error "--max-iterations must be a positive integer"
                    return 1
                fi
                shift 2
                ;;
            --max-budget-usd)
                MAX_BUDGET="${2:?--max-budget-usd requires a value}"
                shift 2
                ;;
            --progress-file)
                PROGRESS_FILE="${2:?--progress-file requires a value}"
                shift 2
                ;;
            --permission-mode)
                PERMISSION_MODE="${2:?--permission-mode requires a value}"
                shift 2
                ;;
            --worktree)
                WORKTREE="${2:?--worktree requires a value}"
                shift 2
                ;;
            --model)
                MODEL="${2:?--model requires a value}"
                shift 2
                ;;
            --bare)
                BARE=true
                shift
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
                log_error "Unexpected argument: $1"
                show_help
                return 1
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

    if [[ -n "$PRD_FILE" ]] && [[ ! -f "$PRD_FILE" ]]; then
        log_error "PRD file not found: $PRD_FILE"
        return 1
    fi
}

# --- Notification ---

ralph_notify() {
    local event="$1" iteration="$2" elapsed="$3"
    [[ "$NOTIFY" != true ]] && return 0

    local creds_file="$HOME/.claude/hooks/.pushover-creds"
    local app_token="${PUSHOVER_APP_TOKEN_CLAUDE:-${PUSHOVER_TOKEN:-}}"
    local user="${PUSHOVER_USER:-}"

    if [[ -z "$app_token" || -z "$user" ]] && [[ -f "$creds_file" ]]; then
        [[ -z "$app_token" ]] && app_token=$(sed -n '1p' "$creds_file")
        [[ -z "$user" ]] && user=$(sed -n '2p' "$creds_file")
    fi

    [[ -z "$app_token" || -z "$user" ]] && return 0

    local message="Ralph $event after $iteration iterations (${elapsed}s)"
    curl -s \
        -F "token=$app_token" \
        -F "user=$user" \
        -F "title=Ralph" \
        -F "message=$message" \
        -F "priority=1" \
        -F "sound=cosmic" \
        https://api.pushover.net/1/messages.json &>/dev/null &
}

# --- Template substitution ---

render_prompt() {
    local iteration="$1" max="$2" progress="$3"
    local prompt
    prompt=$(<"$PROMPT_FILE")
    prompt="${prompt//\{\{ITERATION\}\}/$iteration}"
    prompt="${prompt//\{\{MAX_ITERATIONS\}\}/$max}"
    prompt="${prompt//\{\{PROGRESS_FILE\}\}/$progress}"
    echo "$prompt"
}

# --- Session ID generation ---

generate_session_id() {
    if command -v uuidgen &>/dev/null; then
        uuidgen
    elif [[ -f /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        # Fallback: timestamp + random
        echo "$(date +%s)-$RANDOM-$RANDOM-$RANDOM"
    fi
}

# --- Main loop ---

run_loop() {
    local session_id
    session_id=$(generate_session_id)
    local start_time
    start_time=$(date +%s)
    local iteration=0

    log_section "Ralph: Autonomous Loop"
    log_info "Prompt:     $PROMPT_FILE"
    [[ -n "$PRD_FILE" ]] && log_info "PRD:        $PRD_FILE"
    log_info "Iterations: $MAX_ITERATIONS max"
    if [[ -n "$MAX_BUDGET" ]]; then
        log_info "Budget:     \$$MAX_BUDGET per iteration"
    else
        log_info "Budget:     (unset -- Max subscription mode)"
    fi
    [[ -n "$MODEL" ]] && log_info "Model:      $MODEL"
    log_info "Progress:   $PROGRESS_FILE"
    log_info "Session:    ${session_id:0:8}..."
    [[ -n "$WORKTREE" ]] && log_info "Worktree:   $WORKTREE"

    # Initialize progress file from template if it doesn't exist
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        local template_dir
        template_dir="$(cd "$(dirname "$PROMPT_FILE")" && pwd)"
        if [[ -f "$template_dir/progress.txt" ]]; then
            cp "$template_dir/progress.txt" "$PROGRESS_FILE"
        else
            echo "# Progress Log" > "$PROGRESS_FILE"
        fi
    fi

    # Copy PRD to workdir if provided
    if [[ -n "$PRD_FILE" ]] && [[ ! -f "./PRD.md" ]]; then
        cp "$PRD_FILE" "./PRD.md"
        log_info "Copied PRD to ./PRD.md"
    fi

    while [[ $iteration -lt $MAX_ITERATIONS ]]; do
        iteration=$((iteration + 1))
        local elapsed=$(( $(date +%s) - start_time ))
        log_info "--- Iteration $iteration/$MAX_ITERATIONS (${elapsed}s elapsed) ---"

        # Build claude command
        local -a cmd=(claude --print
            --session-id "$session_id"
            --permission-mode "$PERMISSION_MODE")
        [[ -n "$MAX_BUDGET" ]] && cmd+=(--max-budget-usd "$MAX_BUDGET")
        [[ -n "$MODEL" ]] && cmd+=(--model "$MODEL")
        [[ -n "$WORKTREE" ]] && cmd+=(--worktree "$WORKTREE")
        [[ "$BARE" == true ]] && cmd+=(--bare)

        # Render prompt with substitutions
        local prompt
        prompt=$(render_prompt "$iteration" "$MAX_ITERATIONS" "$PROGRESS_FILE")

        # Run Claude
        local exit_code=0
        "${cmd[@]}" "$prompt" || exit_code=$?

        # Check for completion
        if grep -q '^## COMPLETE' "$PROGRESS_FILE" 2>/dev/null; then
            elapsed=$(( $(date +%s) - start_time ))
            log_success "All tasks complete at iteration $iteration (${elapsed}s)"
            ralph_notify "completed" "$iteration" "$elapsed"
            return 0
        fi

        # Check for errors
        if [[ $exit_code -ne 0 ]]; then
            elapsed=$(( $(date +%s) - start_time ))
            log_error "Claude exited with code $exit_code at iteration $iteration"
            ralph_notify "error (exit $exit_code)" "$iteration" "$elapsed"
            return 1
        fi
    done

    local elapsed=$(( $(date +%s) - start_time ))
    log_warn "Max iterations ($MAX_ITERATIONS) reached (${elapsed}s)"
    ralph_notify "max-iterations" "$MAX_ITERATIONS" "$elapsed"
    return 2
}

# --- Entry point ---

main() {
    parse_args "$@"
    check_dependencies
    run_loop
}

# Allow sourcing for testing without executing main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
