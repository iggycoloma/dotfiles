#!/usr/bin/env bash
# PostToolUse hook: auto-run shellcheck on .sh files after Write/Edit
#
# Input: JSON on stdin with tool_name and tool_input
# Output: JSON to stdout with status and message
# Exit 0 = proceed (informational), Exit 2 = block

# Only run if shellcheck is available
command -v shellcheck &>/dev/null || exit 0

# Parse file path from tool input
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Skip if no file path or not a shell script
[[ -z "$file_path" ]] && exit 0
[[ "$file_path" != *.sh ]] && exit 0
[[ ! -f "$file_path" ]] && exit 0

# Run shellcheck
output=$(shellcheck -f gcc "$file_path" 2>&1)
exit_code=$?

if [[ $exit_code -ne 0 && -n "$output" ]]; then
    # Count warnings/errors
    error_count=$(echo "$output" | grep -c ':.*:' || true)
    echo "shellcheck found $error_count issue(s) in $file_path:"
    echo "$output"
    exit 0  # Informational only, don't block
fi

exit 0
