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
PERMISSION_MODE="plan"
WORKTREE=""
BARE=false
NOTIFY=true
YOLO=false
ITERATION_TIMEOUT="${RALPH_ITERATION_TIMEOUT:-900}"
MAX_WALL_CLOCK="${RALPH_MAX_WALL_CLOCK:-14400}"
UNSAFE_MODE_MAX_ITER_CAP=50
VERIFY_CMD="${RALPH_VERIFY_CMD:-}"
CHECKPOINT=true
CHECKPOINT_PATHS=""
CIRCUIT_BREAKER_THRESHOLD="${RALPH_CIRCUIT_BREAKER:-3}"

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
  --permission-mode <mode>     Claude permission mode (default: plan; use --yolo for acceptEdits)
  --iteration-timeout <secs>   Wall-clock timeout per iteration (default: 900 = 15 min)
  --max-wall-clock <secs>      Total wall-clock budget for the run (default: 14400 = 4h)
  --worktree <branch>          Run in a git worktree
  --model <model>              Model override (e.g., sonnet, opus)
  --bare                       Use bare mode (skip hooks, LSP, plugins)
  --yolo                       Use --permission-mode acceptEdits (auto-approve edits).
                               Equivalent to RALPH_UNSAFE_MODE=1.
  --verify-cmd <command>        Verify command run after each iteration (e.g., "make test").
                               Blocks COMPLETE unless it passes. Default: none.
  --no-checkpoint              Disable automatic git commit after each iteration
  --checkpoint-paths <spec>    Colon-separated paths passed to `git add` for checkpoint
                               commits (default: -A, which stages everything).
                               Example: --checkpoint-paths "src/:tests/"
  --circuit-breaker <N>        Halt after N consecutive iterations with no progress
                               change (default: 3). Set 0 to disable.
  --no-notify                  Disable Pushover notifications
  -h, --help                   Show this help

Environment:
  RALPH_MAX_MODE=1             Max subscription mode: skip budget cap, default
                               to sonnet. Override with --model or --max-budget-usd.
                               Capped at 50 iterations unless RALPH_UNSAFE_MODE=1.
  RALPH_UNSAFE_MODE=1          Equivalent to --yolo. Gates acceptEdits and removes
                               the Max-mode iteration cap. Intended for hardened
                               sandboxes (e.g., the unattended devcontainer profile).
  RALPH_DEFAULT_MODEL          Default model when --model not passed
  RALPH_DEFAULT_BUDGET         Default budget when --max-budget-usd not passed
  RALPH_ITERATION_TIMEOUT      Per-iteration timeout in seconds (default: 900)
  RALPH_MAX_WALL_CLOCK         Total wall-clock budget in seconds (default: 14400)
  RALPH_VERIFY_CMD             Verify command (same as --verify-cmd)
  RALPH_CIRCUIT_BREAKER        Circuit breaker threshold (same as --circuit-breaker)

Guardrails:
  The loop stops when any of these conditions is met:
  - Claude writes "## COMPLETE" to the progress file AND verify passes
  - Max iterations reached
  - Claude exits with an error
  - Per-iteration budget exceeded (--max-budget-usd)
  - Per-iteration wall-clock timeout exceeded (--iteration-timeout)
  - Total wall-clock budget exceeded (--max-wall-clock)
  - Circuit breaker: N consecutive iterations with no progress change

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
            --yolo)
                YOLO=true
                shift
                ;;
            --iteration-timeout)
                ITERATION_TIMEOUT="${2:?--iteration-timeout requires a value}"
                if ! [[ "$ITERATION_TIMEOUT" =~ ^[0-9]+$ ]]; then
                    log_error "--iteration-timeout must be a positive integer (seconds)"
                    return 1
                fi
                shift 2
                ;;
            --max-wall-clock)
                MAX_WALL_CLOCK="${2:?--max-wall-clock requires a value}"
                if ! [[ "$MAX_WALL_CLOCK" =~ ^[0-9]+$ ]]; then
                    log_error "--max-wall-clock must be a positive integer (seconds)"
                    return 1
                fi
                shift 2
                ;;
            --verify-cmd)
                VERIFY_CMD="${2:?--verify-cmd requires a value}"
                shift 2
                ;;
            --no-checkpoint)
                CHECKPOINT=false
                shift
                ;;
            --checkpoint-paths)
                CHECKPOINT_PATHS="${2:?--checkpoint-paths requires a value}"
                shift 2
                ;;
            --circuit-breaker)
                CIRCUIT_BREAKER_THRESHOLD="${2:?--circuit-breaker requires a value}"
                if ! [[ "$CIRCUIT_BREAKER_THRESHOLD" =~ ^[0-9]+$ ]]; then
                    log_error "--circuit-breaker must be a non-negative integer"
                    return 1
                fi
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

# --- Safety resolution ---
#
# Decide the effective permission mode and iteration cap based on --yolo,
# RALPH_UNSAFE_MODE, and RALPH_MAX_MODE. Emits warnings for dangerous
# combinations.

resolve_safety() {
    local unsafe=false
    if [[ "$YOLO" == true ]] || [[ "${RALPH_UNSAFE_MODE:-0}" == "1" ]]; then
        unsafe=true
    fi

    # --yolo / RALPH_UNSAFE_MODE unlocks acceptEdits. Without it, we stay in
    # plan mode by default so the agent cannot auto-approve file edits.
    if [[ "$unsafe" == true ]] && [[ "$PERMISSION_MODE" == "plan" ]]; then
        PERMISSION_MODE="acceptEdits"
    fi

    # Cap iterations under RALPH_MAX_MODE unless the user has explicitly
    # opted into unsafe mode. Rationale: without a budget cap, a stuck
    # loop at 20+ iterations can burn significant time and API usage.
    if [[ "${RALPH_MAX_MODE:-0}" == "1" ]]; then
        log_warn "RALPH_MAX_MODE=1: budget cap is disabled (rate-limit gated only)."
        if [[ "$unsafe" != true ]] && [[ "$MAX_ITERATIONS" -gt "$UNSAFE_MODE_MAX_ITER_CAP" ]]; then
            log_warn "Capping --max-iterations at $UNSAFE_MODE_MAX_ITER_CAP under RALPH_MAX_MODE."
            log_warn "Set RALPH_UNSAFE_MODE=1 or pass --yolo to remove the cap."
            MAX_ITERATIONS=$UNSAFE_MODE_MAX_ITER_CAP
        fi
    fi

    # Loud warning when --bare (which skips hooks) combines with acceptEdits.
    # This bypasses every guardrail: pre-security, pre-commit-validate,
    # pre-code-no-emoji, and any PostToolUse audit.
    if [[ "$BARE" == true ]] && [[ "$PERMISSION_MODE" == "acceptEdits" ]]; then
        log_warn "=================================================================="
        log_warn "DANGER: --bare + --permission-mode acceptEdits disables ALL hooks"
        log_warn "and auto-approves every file edit. The credential deny list in"
        log_warn "settings.json still applies, but hook-based scope/emoji/commit"
        log_warn "checks do NOT. Only use inside a hardened sandbox."
        log_warn "=================================================================="
    fi

    if [[ "$PERMISSION_MODE" == "acceptEdits" ]] && [[ "$unsafe" != true ]]; then
        # Under CLAUDE_UNATTENDED=1 the whole point of --yolo gating is an
        # explicit opt-in. Reject the implicit path.
        if [[ "${CLAUDE_UNATTENDED:-0}" == "1" ]]; then
            log_error "--permission-mode acceptEdits requires --yolo under CLAUDE_UNATTENDED=1."
            log_error "Pass --yolo or set RALPH_UNSAFE_MODE=1 to opt into auto-approved edits."
            return 1
        fi
        log_warn "--permission-mode acceptEdits was set without --yolo / RALPH_UNSAFE_MODE."
        log_warn "This auto-approves file edits. Prefer --yolo so the intent is explicit."
    fi
}

# --- Notification ---

# Returns 0 if the file is owner-readable only (mode 0600 or 0400).
# Cross-platform: GNU stat and BSD stat have different flags.
creds_file_secure() {
    local f="$1" mode=""
    if mode=$(stat -c '%a' "$f" 2>/dev/null); then
        : # GNU stat
    elif mode=$(stat -f '%Lp' "$f" 2>/dev/null); then
        : # BSD stat
    else
        # Cannot stat; be conservative.
        return 1
    fi
    # Reject anything with group or other permission bits.
    case "$mode" in
        600|400|200|000) return 0 ;;
        *) return 1 ;;
    esac
}

ralph_notify() {
    local event="$1" iteration="$2" elapsed="$3"
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

# --- Verification ---

run_verify() {
    [[ -z "$VERIFY_CMD" ]] && return 0
    log_info "Verifying: $VERIFY_CMD"
    local rc=0
    eval "$VERIFY_CMD" >/dev/null 2>&1 || rc=$?
    if [[ $rc -ne 0 ]]; then
        log_warn "Verify failed (exit $rc): $VERIFY_CMD"
    else
        log_info "Verify passed."
    fi
    return $rc
}

# --- Git checkpoint ---

git_checkpoint() {
    [[ "$CHECKPOINT" != true ]] && return 0
    if ! command -v git &>/dev/null; then return 0; fi
    if ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then return 0; fi

    local iteration="$1"
    if git diff --quiet && git diff --cached --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
        log_info "Checkpoint: nothing to commit."
        return 0
    fi
    if [[ -n "$CHECKPOINT_PATHS" ]]; then
        # Split on ':' into an array of paths for scoped staging.
        local -a paths=()
        IFS=':' read -r -a paths <<<"$CHECKPOINT_PATHS"
        git add -- "${paths[@]}"
    else
        git add -A
    fi
    git commit -q -m "chore(ralph): checkpoint iteration $iteration" || true
    log_info "Checkpoint: committed iteration $iteration."
}

# Re-initialize the progress file if the agent deleted it mid-run.
# Called at the top of every iteration.
ensure_progress_file() {
    [[ -f "$PROGRESS_FILE" ]] && return 0
    log_warn "progress file vanished at $PROGRESS_FILE; re-initializing from template."
    local template_dir
    template_dir="$(cd "$(dirname "$PROMPT_FILE")" && pwd)"
    if [[ -f "$template_dir/progress.txt" ]]; then
        cp "$template_dir/progress.txt" "$PROGRESS_FILE"
    else
        echo "# Progress Log" > "$PROGRESS_FILE"
    fi
}

# --- Circuit breaker ---

progress_hash() {
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        echo "empty"
        return
    fi
    # Portable cascade: GNU md5sum (Linux/Alpine), BSD md5 (macOS),
    # stat fingerprint as last resort. Without this, macOS returns empty
    # and the circuit breaker trips on every iteration.
    if command -v md5sum &>/dev/null; then
        md5sum "$PROGRESS_FILE" 2>/dev/null | cut -d' ' -f1
    elif command -v md5 &>/dev/null; then
        md5 -q "$PROGRESS_FILE" 2>/dev/null
    elif stat -c '%Y-%s' "$PROGRESS_FILE" &>/dev/null; then
        stat -c '%Y-%s' "$PROGRESS_FILE"
    else
        stat -f '%m-%z' "$PROGRESS_FILE" 2>/dev/null || echo "unknown"
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
    log_info "Permission: $PERMISSION_MODE"
    [[ -n "$VERIFY_CMD" ]] && log_info "Verify:     $VERIFY_CMD"
    log_info "Checkpoint: $CHECKPOINT"
    [[ "$CIRCUIT_BREAKER_THRESHOLD" -gt 0 ]] && log_info "Circuit-brk: $CIRCUIT_BREAKER_THRESHOLD consecutive stalls"
    log_info "Iter-to:    ${ITERATION_TIMEOUT}s"
    log_info "Wall-clock: ${MAX_WALL_CLOCK}s (total)"
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

    local have_timeout=false
    if command -v timeout &>/dev/null; then
        have_timeout=true
    else
        log_warn "coreutils 'timeout' not found; per-iteration timeout disabled."
    fi

    # Circuit breaker state
    local prev_hash=""
    local stall_count=0
    prev_hash=$(progress_hash)

    while [[ $iteration -lt $MAX_ITERATIONS ]]; do
        iteration=$((iteration + 1))
        local elapsed=$(( $(date +%s) - start_time ))

        # Total wall-clock guard before firing the next iteration.
        if [[ $elapsed -ge $MAX_WALL_CLOCK ]]; then
            log_warn "Max wall-clock ($MAX_WALL_CLOCK s) reached at iteration $iteration (${elapsed}s)"
            ralph_notify "wall-clock-exceeded" "$iteration" "$elapsed"
            return 3
        fi

        log_info "--- Iteration $iteration/$MAX_ITERATIONS (${elapsed}s elapsed) ---"

        ensure_progress_file

        # Build claude command
        local -a cmd=()
        if [[ "$have_timeout" == true ]]; then
            cmd+=(timeout --kill-after=10 "$ITERATION_TIMEOUT")
        fi
        cmd+=(claude --print
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

        # timeout(1) returns 124 on SIGTERM, 137 on SIGKILL.
        if [[ $exit_code -eq 124 ]] || [[ $exit_code -eq 137 ]]; then
            elapsed=$(( $(date +%s) - start_time ))
            log_error "Iteration $iteration timed out after ${ITERATION_TIMEOUT}s (exit $exit_code)"
            ralph_notify "iteration-timeout" "$iteration" "$elapsed"
            return 4
        fi

        # Check for errors (before verify/checkpoint — nothing to gate on a crash).
        if [[ $exit_code -ne 0 ]]; then
            elapsed=$(( $(date +%s) - start_time ))
            log_error "Claude exited with code $exit_code at iteration $iteration"
            ralph_notify "error (exit $exit_code)" "$iteration" "$elapsed"
            return 1
        fi

        # --- Post-iteration verification ---
        local verify_passed=true
        if ! run_verify; then
            verify_passed=false
        fi

        # Completion gate: agent wrote ## COMPLETE, but only accept if verify passes.
        if grep -q '^## COMPLETE' "$PROGRESS_FILE" 2>/dev/null; then
            if [[ "$verify_passed" == true ]]; then
                git_checkpoint "$iteration"
                elapsed=$(( $(date +%s) - start_time ))
                log_success "All tasks complete at iteration $iteration (${elapsed}s)"
                ralph_notify "completed" "$iteration" "$elapsed"
                return 0
            else
                log_warn "## COMPLETE found but verify failed. Removing sentinel; loop continues."
                # Portable rewrite (BSD/macOS sed -i needs an argument).
                local tmp
                tmp=$(mktemp)
                grep -v '^## COMPLETE' "$PROGRESS_FILE" > "$tmp" || true
                mv "$tmp" "$PROGRESS_FILE"
            fi
        fi

        # --- Git checkpoint ---
        git_checkpoint "$iteration"

        # --- Circuit breaker ---
        local cur_hash
        cur_hash=$(progress_hash)
        if [[ "$cur_hash" == "$prev_hash" ]]; then
            stall_count=$((stall_count + 1))
            log_warn "No progress change (stall $stall_count/$CIRCUIT_BREAKER_THRESHOLD)"
        else
            stall_count=0
            prev_hash="$cur_hash"
        fi

        if [[ "$CIRCUIT_BREAKER_THRESHOLD" -gt 0 ]] && [[ $stall_count -ge $CIRCUIT_BREAKER_THRESHOLD ]]; then
            elapsed=$(( $(date +%s) - start_time ))
            log_error "Circuit breaker: $stall_count consecutive iterations with no progress change."
            ralph_notify "stuck (circuit-breaker)" "$iteration" "$elapsed"
            return 5
        fi
    done

    local elapsed=$(( $(date +%s) - start_time ))
    log_warn "Max iterations ($MAX_ITERATIONS) reached (${elapsed}s)"
    ralph_notify "max-iterations" "$MAX_ITERATIONS" "$elapsed"
    return 2
}

# --- Entry point ---

main() {
    parse_args "$@" || return $?
    check_dependencies || return $?
    # Explicit propagation: `set -e` does not reliably kill the script when a
    # nested function returns non-zero from inside a conditional (known bash
    # quirk around inherit_errexit). The || chain makes the intent explicit.
    resolve_safety || return $?
    run_loop
}

# Allow sourcing for testing without executing main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
