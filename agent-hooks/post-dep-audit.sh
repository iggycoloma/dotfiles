#!/usr/bin/env bash
# Audit the resolved dependency graph after a successful install command.

command -v jq &>/dev/null || exit 0
input=$(cat)
[[ "$(printf '%s' "$input" | jq -r '.tool_name // empty')" == "Bash" ]] || exit 0
command_text=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[[ -n "$command_text" ]] || exit 0
tool_rc=$(printf '%s' "$input" | jq -r '.tool_response.exit_code? // .tool_response.exitCode? // 0')
[[ "$tool_rc" =~ ^[0-9]+$ && "$tool_rc" -ne 0 ]] && exit 0

ecosystem=""
if [[ "$command_text" =~ (^|[[:space:]])(npm|pnpm)[[:space:]]+(install|i|ci)([[:space:]]|$) ]] \
   || [[ "$command_text" =~ (^|[[:space:]])yarn[[:space:]]+(install|add)([[:space:]]|$) ]] \
   || [[ "$command_text" =~ (^|[[:space:]])bun[[:space:]]+(install|add)([[:space:]]|$) ]]; then
    ecosystem=npm
elif [[ "$command_text" =~ (^|[[:space:]])(pip|pip3|pipx)[[:space:]]+install([[:space:]]|$) ]] \
   || [[ "$command_text" =~ (^|[[:space:]])uv[[:space:]]+(add|sync|pip[[:space:]]+install)([[:space:]]|$) ]] \
   || [[ "$command_text" =~ (^|[[:space:]])poetry[[:space:]]+(add|install|update)([[:space:]]|$) ]]; then
    ecosystem=pip
elif [[ "$command_text" =~ (^|[[:space:]])cargo[[:space:]]+(add|install|update)([[:space:]]|$) ]]; then
    ecosystem=cargo
elif [[ "$command_text" =~ (^|[[:space:]])go[[:space:]]+(get|install|mod[[:space:]]+download)([[:space:]]|$) ]]; then
    ecosystem=go
else
    exit 0
fi

project_dir=$(printf '%s' "$input" | jq -r '.cwd // empty')
project_dir="${project_dir:-${CLAUDE_PROJECT_DIR:-$PWD}}"
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/agent-hooks"
mkdir -p "$log_dir" 2>/dev/null || exit 0
audit_log="$log_dir/dependency-audit.log"
audit_rc=0
audit_output=""
case "$ecosystem" in
    npm)
        if ! command -v npm &>/dev/null; then
            printf 'dependency audit skipped: npm is unavailable\n' >&2
            exit 0
        fi
        audit_output=$(cd "$project_dir" && npm audit --audit-level=high --json 2>&1) || audit_rc=$?
        ;;
    pip)
        if ! command -v pip-audit &>/dev/null; then
            printf 'dependency audit skipped: pip-audit is unavailable\n' >&2
            exit 0
        fi
        audit_output=$(cd "$project_dir" && pip-audit --format=json 2>&1) || audit_rc=$?
        ;;
    cargo)
        if ! command -v cargo-audit &>/dev/null; then
            printf 'dependency audit skipped: cargo-audit is unavailable\n' >&2
            exit 0
        fi
        audit_output=$(cd "$project_dir" && cargo audit --json 2>&1) || audit_rc=$?
        ;;
    go)
        if ! command -v govulncheck &>/dev/null; then
            printf 'dependency audit skipped: govulncheck is unavailable\n' >&2
            exit 0
        fi
        audit_output=$(cd "$project_dir" && govulncheck ./... 2>&1) || audit_rc=$?
        ;;
esac

printf '%s ecosystem=%s rc=%s project=%s\n' "$(date -Is)" "$ecosystem" "$audit_rc" "$(basename "$project_dir")" >> "$audit_log"
[[ $audit_rc -ne 0 ]] || exit 0
printf '%s\n' "$audit_output" >> "$audit_log"
printf 'dependency audit failed (%s, exit %s); review %s\n' "$ecosystem" "$audit_rc" "$audit_log" >&2
if [[ "${AGENT_DEP_AUDIT_FEEDBACK:-0}" == "1" ]]; then
    exit 2
fi
