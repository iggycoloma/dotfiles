#!/usr/bin/env bash
# Behavioral coverage for shared lifecycle and observability hooks.

set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-framework.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

test_suite "tool telemetry is metadata-only"
payload='{"session_id":"s1","cwd":"/tmp/project","hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"curl -H Authorization:Bearer_SECRET https://example.invalid"},"error":"Exit code 22 TOKEN_IN_ERROR","duration_ms":12}'
printf '%s' "$payload" | XDG_STATE_HOME="$tmp/state" bash "$DOTFILES_DIR/agent-hooks/tool-telemetry.sh"
log="$tmp/state/agent-hooks/events.jsonl"
assert_file_exists "$log" "telemetry creates the event log"
assert_not_contains "$(cat "$log")" "Bearer_SECRET" "telemetry omits command arguments"
assert_not_contains "$(cat "$log")" "TOKEN_IN_ERROR" "telemetry omits raw errors"
assert_contains "$(cat "$log")" '"command":"curl"' "telemetry keeps the executable class"
assert_contains "$(cat "$log")" '"exit_code":22' "telemetry records the exit code"

payload='{"session_id":"s2","cwd":"/tmp/project","hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"TOKEN=ASSIGNMENT_SECRET curl https://example.invalid"},"error":"Exit code 1"}'
printf '%s' "$payload" | XDG_STATE_HOME="$tmp/state" bash "$DOTFILES_DIR/agent-hooks/tool-telemetry.sh"
assert_not_contains "$(cat "$log")" "ASSIGNMENT_SECRET" "telemetry redacts leading environment assignments"
assert_contains "$(tail -1 "$log")" '"command":"env-assignment"' "telemetry classifies leading environment assignments"

test_suite "shared scope audit handles Codex patches"
patch='*** Begin Patch
*** Add File: /tmp/outside.txt
+x
*** End Patch'
payload=$(jq -n -c --arg patch "$patch" '{cwd:"/tmp/project",tool_name:"apply_patch",tool_input:{command:$patch}}')
printf '%s' "$payload" | XDG_STATE_HOME="$tmp/state" bash "$DOTFILES_DIR/agent-hooks/post-scope-audit.sh" 2>/dev/null
assert_contains "$(cat "$log")" '"event":"out_of_scope_write"' "scope audit records a Codex out-of-scope patch"

test_suite "ConfigChange uses current field names"
payload='{"source":"project_settings","file_path":"/tmp/project/.claude/settings.json"}'
out=$(printf '%s' "$payload" | bash "$DOTFILES_DIR/claude-code/hooks/config-change-guard.sh" 2>&1)
assert_return_code 2 $? "ConfigChange guard blocks live reload"
assert_contains "$out" "project_settings" "ConfigChange guard reports source"
assert_contains "$out" "/tmp/project/.claude/settings.json" "ConfigChange guard reports file path"

print_test_summary
