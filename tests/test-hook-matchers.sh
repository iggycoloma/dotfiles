#!/usr/bin/env bash
# Tests that every tool-hook matcher in the agent configs resolves to a tool
# name the target platform actually emits, and that the wired hook dispatches
# on at least one of them.
#
# Why this exists: tests/test-security-hook.sh and tests/test-emoji-hook.sh
# pipe payloads straight into agent-hooks/*.sh, bypassing the matcher wiring in
# claude-code/settings.json and codex/hooks.json. A matcher naming a tool the
# platform never emits leaves the hook silently unreachable while both suites
# stay green. That is exactly how codex/hooks.json shipped Read|Write|Edit
# matchers -- Codex has no such tools, only apply_patch -- so its no-emoji
# guard and file-path guard never fired.
#
# Note: the emoji probe string is built with printf so this file stays
# emoji-free and does not trip pre-code-no-emoji.sh on itself.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR_REAL="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/test-framework.sh"

CLAUDE_SETTINGS="$DOTFILES_DIR_REAL/claude-code/settings.json"
CODEX_HOOKS="$DOTFILES_DIR_REAL/codex/hooks.json"
SECURITY_HOOK="$DOTFILES_DIR_REAL/agent-hooks/pre-security.sh"
EMOJI_HOOK="$DOTFILES_DIR_REAL/agent-hooks/pre-code-no-emoji.sh"
HOOKSPATH_HOOK="$DOTFILES_DIR_REAL/agent-hooks/pre-hookspath-guard.sh"

# Pin HOME so the hooks' $HOME-anchored path checks match the fixtures below.
FIXTURE_HOME=/home/vscode
ROCKET=$(printf '\xF0\x9F\x9A\x80')

# Tool names each platform can emit to a PreToolUse/PostToolUse hook. These are
# the universes a matcher is checked against; a matcher matching nothing here is
# dead wiring.
CLAUDE_TOOLS=(
    Bash Read Write Edit MultiEdit NotebookEdit
    Glob Grep WebFetch WebSearch Task TodoWrite
)
# Codex fires tool hooks for shell, apply_patch, MCP calls, and most local
# function tools. Edit/Write are matcher aliases for apply_patch, not canonical
# payload tool names.
#
# unified_exec is deliberately absent: it fires PreToolUse but reports
# tool_name "Bash" with a string tool_input.command, so it never appears here as
# its own name and the Bash entry already covers it. view_image is absent
# because its handler emits no hook events (openai/codex#20204).
CODEX_TOOLS=(
    Bash apply_patch update_plan spawn_agent mcp__filesystem__read_file
)

# ---------------------------------------------------------------------------
# Probes: build a payload that MUST be denied if the hook dispatches on $tool.
# Empty output means we have no discriminating probe for that pair.
# ---------------------------------------------------------------------------

probe_payload() {
    local hook="$1" tool="$2" patch

    case "$hook" in
        "$SECURITY_HOOK")
            case "$tool" in
                Bash)
                    # Also the shape Codex sends for unified_exec, which reports
                    # itself as Bash with a string command.
                    jq -n -c --arg t "$tool" \
                        '{tool_name:$t,tool_input:{command:"cat ~/.ssh/id_rsa"}}'
                    ;;
                apply_patch)
                    patch='*** Begin Patch
*** Add File: .env
+TOKEN=x
*** End Patch'
                    jq -n -c --arg t "$tool" --arg p "$patch" \
                        '{tool_name:$t,tool_input:{command:$p}}'
                    ;;
                mcp__filesystem__read_file)
                    jq -n -c --arg t "$tool" \
                        '{tool_name:$t,tool_input:{path:"/home/vscode/.aws/credentials"}}'
                    ;;
                Read|Write|Edit|MultiEdit|NotebookEdit)
                    jq -n -c --arg t "$tool" \
                        '{tool_name:$t,tool_input:{file_path:"/home/vscode/.aws/credentials"}}'
                    ;;
            esac
            ;;
        "$EMOJI_HOOK")
            case "$tool" in
                Write)
                    jq -n -c --arg t "$tool" --arg c "greet() { echo $ROCKET; }" \
                        '{tool_name:$t,tool_input:{file_path:"/tmp/probe.sh",content:$c}}'
                    ;;
                Edit)
                    jq -n -c --arg t "$tool" --arg n "echo $ROCKET" \
                        '{tool_name:$t,tool_input:{file_path:"/tmp/probe.sh",old_string:"old",new_string:$n}}'
                    ;;
                MultiEdit)
                    jq -n -c --arg t "$tool" --arg n "echo $ROCKET" \
                        '{tool_name:$t,tool_input:{file_path:"/tmp/probe.sh",edits:[{old_string:"old",new_string:$n}]}}'
                    ;;
                apply_patch)
                    patch="*** Begin Patch
*** Update File: probe.sh
+echo $ROCKET
*** End Patch"
                    jq -n -c --arg t "$tool" --arg p "$patch" \
                        '{tool_name:$t,tool_input:{command:$p}}'
                    ;;
            esac
            ;;
        "$HOOKSPATH_HOOK")
            case "$tool" in
                Bash)
                    jq -n -c --arg t "$tool" \
                        '{tool_name:$t,tool_input:{command:"git config core.hooksPath .githooks"}}'
                    ;;
            esac
            ;;
    esac
}

# "dispatched" if the hook returns any decision for the probe, "inert" if it
# fell through. Accepts ask as well as deny: pre-security.sh emits ask by
# default and the Codex wrapper is what rewrites it to deny, so requiring deny
# here would report a live hook as dead.
probe_dispatch() {
    local hook="$1" tool="$2" payload result
    payload=$(probe_payload "$hook" "$tool")
    [[ -z "$payload" ]] && { echo "inert"; return; }

    result=$(printf '%s' "$payload" | HOME="$FIXTURE_HOME" bash "$hook" 2>/dev/null)
    if printf '%s' "$result" | jq -e '
        .hookSpecificOutput.permissionDecision
        | . == "deny" or . == "ask" or . == "block"
    ' >/dev/null 2>&1; then
        echo "dispatched"
    else
        echo "inert"
    fi
}

# Resolve a hooks.json command string to a shared implementation we can probe.
resolve_hook() {
    case "$1" in
        *pre-security.sh) printf '%s' "$SECURITY_HOOK" ;;
        *pre-code-no-emoji.sh) printf '%s' "$EMOJI_HOOK" ;;
        *pre-hookspath-guard.sh) printf '%s' "$HOOKSPATH_HOOK" ;;
        *) printf '' ;;
    esac
}

# ---------------------------------------------------------------------------
# The contract check, run per platform config.
# ---------------------------------------------------------------------------

check_config() {
    local label="$1" config="$2"
    shift 2
    local -a universe=("$@")

    local entries
    entries=$(jq -c '
        (.hooks // .) as $h
        | ($h.PreToolUse // []) + ($h.PostToolUse // [])
        | to_entries[]
        | select(.value.matcher != null)
        | {i: .key, matcher: .value.matcher,
           commands: [.value.hooks[]?.command]}
    ' "$config" 2>/dev/null)

    if [[ -z "$entries" ]]; then
        test_fail "$label: found no tool-hook entries to check"
        return
    fi

    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        local matcher matched tool
        matcher=$(printf '%s' "$entry" | jq -r '.matcher')

        # Layer 1: the matcher must select at least one real tool name.
        matched=()
        for tool in "${universe[@]}"; do
            if printf '%s' "$tool" | grep -qE -- "$matcher" 2>/dev/null; then
                matched+=("$tool")
            fi
        done

        if [[ ${#matched[@]} -eq 0 ]]; then
            test_fail "$label: matcher '$matcher' matches no tool this platform emits"
            continue
        fi
        test_pass "$label: matcher '$matcher' matches ${matched[*]}"

        # Layer 2: the wired hook must dispatch on at least one matched tool.
        local cmd hook live
        while IFS= read -r cmd; do
            [[ -z "$cmd" ]] && continue
            hook=$(resolve_hook "$cmd")
            if [[ -z "$hook" ]]; then
                test_info "$label: no probe for $(basename "$cmd") -- matcher checked only"
                continue
            fi

            live=""
            for tool in "${matched[@]}"; do
                if [[ "$(probe_dispatch "$hook" "$tool")" == "dispatched" ]]; then
                    live="$tool"
                    break
                fi
            done

            if [[ -n "$live" ]]; then
                test_pass "$label: $(basename "$cmd") dispatches on $live"
            else
                test_fail "$label: $(basename "$cmd") dispatches on none of: ${matched[*]}"
            fi
        done < <(printf '%s' "$entry" | jq -r '.commands[]')
    done <<< "$entries"
}

# ---------------------------------------------------------------------------

test_suite "hook matchers: fixtures present"

assert_file_exists "$CLAUDE_SETTINGS" "claude-code/settings.json exists"
assert_file_exists "$CODEX_HOOKS" "codex/hooks.json exists"
assert_file_exists "$SECURITY_HOOK" "agent-hooks/pre-security.sh exists"
assert_file_exists "$EMOJI_HOOK" "agent-hooks/pre-code-no-emoji.sh exists"
assert_file_exists "$HOOKSPATH_HOOK" "agent-hooks/pre-hookspath-guard.sh exists"

jq -e . "$CODEX_HOOKS" >/dev/null 2>&1
assert_return_code 0 $? "codex/hooks.json is valid JSON"
jq -e . "$CLAUDE_SETTINGS" >/dev/null 2>&1
assert_return_code 0 $? "claude-code/settings.json is valid JSON"

# ---------------------------------------------------------------------------

test_suite "hook matchers: probes are discriminating"

# Guard the guard: if these self-checks drift, Layer 2 silently passes.
# Bash is inert by design -- the command-string scan was retired in favour of
# sandbox.credentials; see docs/sandbox.md "Why there is no Bash scan".
assert_equals "inert" "$(probe_dispatch "$SECURITY_HOOK" Bash)" \
    "security probe treats Bash as inert"
assert_equals "dispatched" "$(probe_dispatch "$SECURITY_HOOK" apply_patch)" \
    "security probe denies a sensitive apply_patch path"
assert_equals "inert" "$(probe_dispatch "$SECURITY_HOOK" Glob)" \
    "security probe treats Glob as inert"
assert_equals "dispatched" "$(probe_dispatch "$EMOJI_HOOK" apply_patch)" \
    "emoji probe denies an emoji in an apply_patch added line"
assert_equals "inert" "$(probe_dispatch "$EMOJI_HOOK" Bash)" \
    "emoji probe treats Bash as inert"

# ---------------------------------------------------------------------------

test_suite "hook matchers: claude-code/settings.json"

check_config "claude-code" "$CLAUDE_SETTINGS" "${CLAUDE_TOOLS[@]}"

# ---------------------------------------------------------------------------

test_suite "hook matchers: codex/hooks.json"

check_config "codex" "$CODEX_HOOKS" "${CODEX_TOOLS[@]}"

# ---------------------------------------------------------------------------

test_suite "hook matchers: regression -- Claude tool names in Codex config"

# Codex emits no canonical Read/MultiEdit payload tool. Edit and Write are
# supported matcher aliases and therefore are not dead wiring.
for dead in "^Read$" "MultiEdit"; do
    hit=0
    for tool in "${CODEX_TOOLS[@]}"; do
        if printf '%s' "$tool" | grep -qE -- "$dead" 2>/dev/null; then
            hit=1
            break
        fi
    done
    assert_equals 0 "$hit" "Codex universe rejects Claude-only matcher '$dead'"
done

# ---------------------------------------------------------------------------

print_test_summary
