#!/usr/bin/env bash
# PostToolUse hook -- run a dependency security audit after any install command.
#
# Detects common install invocations in Bash tool calls (npm install, pip
# install, cargo add, go get, apt install). For each match, runs the matching
# audit tool and appends a WARNING line to the project's progress.txt if
# vulnerabilities are found. Also writes a timestamped entry to
# ~/.local/state/ralph/audit.log.
#
# Non-blocking by default: the tool call still succeeds even if the audit
# finds issues (the warning lands in progress.txt for the agent to read next
# iteration). Set RALPH_AUDIT_BLOCKING=1 to deny the tool call on
# high/critical findings instead.

if ! command -v jq &>/dev/null; then
    exit 0
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
[[ "$TOOL_NAME" != "Bash" ]] && exit 0

COMMAND=$(echo "$input" | jq -r '.tool_input.command // empty')
[[ -z "$COMMAND" ]] && exit 0

detect_ecosystem() {
    local cmd="$1"
    # Use regex because substring-glob patterns overlap in unhelpful ways
    # (e.g. "npm install" is a substring of "pnpm install").
    if [[ "$cmd" =~ (^|[[:space:]])(npm|pnpm)[[:space:]]+(install|i|ci)([[:space:]]|$) ]] \
       || [[ "$cmd" =~ (^|[[:space:]])yarn[[:space:]]+(install|add)([[:space:]]|$) ]]; then
        echo "npm"; return
    fi
    if [[ "$cmd" =~ (^|[[:space:]])(pip|pip3)[[:space:]]+install([[:space:]]|$) ]] \
       || [[ "$cmd" =~ (^|[[:space:]])uv[[:space:]]+(add|pip[[:space:]]+install)([[:space:]]|$) ]] \
       || [[ "$cmd" =~ (^|[[:space:]])poetry[[:space:]]+(add|install)([[:space:]]|$) ]]; then
        echo "pip"; return
    fi
    if [[ "$cmd" =~ (^|[[:space:]])cargo[[:space:]]+(add|install|update)([[:space:]]|$) ]]; then
        echo "cargo"; return
    fi
    if [[ "$cmd" =~ (^|[[:space:]])go[[:space:]]+(get|install|mod[[:space:]]+download)([[:space:]]|$) ]]; then
        echo "go"; return
    fi
    if [[ "$cmd" =~ (^|[[:space:]])(apt|apt-get)[[:space:]]+install([[:space:]]|$) ]]; then
        echo "apt"; return
    fi
    echo ""
}

ecosystem=$(detect_ecosystem "$COMMAND")
[[ -z "$ecosystem" ]] && exit 0

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ralph"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0
AUDIT_LOG="$LOG_DIR/audit.log"
PROGRESS_FILE="${CLAUDE_PROJECT_DIR:-$PWD}/progress.txt"

run_audit() {
    local eco="$1" rc=0 out=""
    case "$eco" in
        npm)
            if command -v npm &>/dev/null; then
                out=$(cd "${CLAUDE_PROJECT_DIR:-$PWD}" && npm audit --audit-level=high --json 2>&1) || rc=$?
            else
                echo "npm not installed" ; return 0
            fi
            ;;
        pip)
            if command -v pip-audit &>/dev/null; then
                out=$(cd "${CLAUDE_PROJECT_DIR:-$PWD}" && pip-audit --format=json 2>&1) || rc=$?
            else
                echo "pip-audit not installed" ; return 0
            fi
            ;;
        cargo)
            if command -v cargo-audit &>/dev/null; then
                out=$(cd "${CLAUDE_PROJECT_DIR:-$PWD}" && cargo audit --json 2>&1) || rc=$?
            else
                echo "cargo-audit not installed" ; return 0
            fi
            ;;
        go)
            if command -v govulncheck &>/dev/null; then
                out=$(cd "${CLAUDE_PROJECT_DIR:-$PWD}" && govulncheck ./... 2>&1) || rc=$?
            else
                echo "govulncheck not installed" ; return 0
            fi
            ;;
        apt)
            # No built-in vuln audit; osv-scanner can inspect a lockfile-equivalent
            # but apt is a weaker signal. Skip by default.
            return 0
            ;;
    esac

    printf '%s\n' "$out"
    return $rc
}

stamp=$(date -Is 2>/dev/null || date)
audit_output=$(run_audit "$ecosystem")
audit_rc=$?

printf '%s  ecosystem=%s  rc=%s\n' "$stamp" "$ecosystem" "$audit_rc" >> "$AUDIT_LOG"

if [[ $audit_rc -eq 0 ]]; then
    # Clean audit: silent success.
    exit 0
fi

# The warning lands in progress.txt for the agent to read next iteration.
if [[ -f "$PROGRESS_FILE" ]]; then
    {
        printf '\n## Audit Warning (iteration end)\n'
        printf '- %s  %s install detected; audit exit %s\n' "$stamp" "$ecosystem" "$audit_rc"
        printf '- See %s for full output.\n' "$AUDIT_LOG"
    } >> "$PROGRESS_FILE"
fi

{
    printf '%s  ecosystem=%s  command=%s\n' "$stamp" "$ecosystem" "$COMMAND"
    printf '%s\n' "$audit_output"
    printf -- '--- end audit ---\n'
} >> "$AUDIT_LOG"

# Also surface to stderr.
printf 'post-dep-audit: %s audit exited %s (command: %s)\n' "$ecosystem" "$audit_rc" "$COMMAND" >&2

# Blocking mode: deny the tool call on any non-zero audit exit.
if [[ "${RALPH_AUDIT_BLOCKING:-0}" == "1" ]]; then
    jq -n -c --arg reason "Dependency audit failed ($ecosystem, exit $audit_rc). See $AUDIT_LOG." \
        '{hookSpecificOutput: {hookEventName: "PostToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
fi

exit 0
