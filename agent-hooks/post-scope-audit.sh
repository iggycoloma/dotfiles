#!/usr/bin/env bash
# Audit file writes outside the active project without blocking them.

command -v jq &>/dev/null || exit 0
input=$(cat)
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty')
scope_root="${AGENT_SCOPE_ROOT:-${CLAUDE_SCOPE_ROOT:-${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // empty')}}}"
[[ -n "$scope_root" ]] || scope_root="$PWD"

paths=""
case "$tool_name" in
    Write|Edit|MultiEdit)
        paths=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
        ;;
    apply_patch)
        patch=$(printf '%s' "$input" | jq -r '.tool_input.command // .tool_input.patch // empty')
        paths=$(printf '%s\n' "$patch" | awk '/^\*\*\* (Add|Update|Delete) File: |^\*\*\* Move to: / {sub(/^.*: /, ""); print}')
        ;;
    *) exit 0 ;;
esac
[[ -n "$paths" ]] || exit 0

canonicalize() {
    if command -v realpath &>/dev/null; then
        realpath -m "$1" 2>/dev/null || printf '%s\n' "$1"
    elif [[ "$1" == /* ]]; then
        printf '%s\n' "$1"
    else
        printf '%s/%s\n' "$PWD" "$1"
    fi
}

absolute_scope=$(canonicalize "$scope_root")
absolute_scope="${absolute_scope%/}"
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/agent-hooks"

while IFS= read -r file_path; do
    [[ -n "$file_path" ]] || continue
    absolute_file=$(canonicalize "$file_path")
    case "$absolute_file" in
        "$absolute_scope"|"$absolute_scope"/*) continue ;;
    esac
    mkdir -p "$log_dir" 2>/dev/null || exit 0
    jq -n -c --arg ts "$(date -Is)" --arg tool "$tool_name" \
        --arg scope "$absolute_scope" --arg path "$absolute_file" \
        '{ts:$ts,event:"out_of_scope_write",tool:$tool,scope:$scope,path:$path}' \
        >> "$log_dir/events.jsonl" 2>/dev/null
    printf 'scope-audit: %s wrote outside %s\n' "$tool_name" "$absolute_scope" >&2
done <<< "$paths"

