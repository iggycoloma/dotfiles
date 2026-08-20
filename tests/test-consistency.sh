#!/usr/bin/env bash
# Consistency tests for instruction files and hook patterns
# Validates that credential deny lists and detection patterns stay in sync
# across all instruction files and hooks.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/test-framework.sh"

# ============================================================================
# Helpers: extract deny lists from instruction files
# ============================================================================

# Extract the credential directories line from a file.
# Matches "Never access credential directories:" followed by a comma-separated list.
extract_credential_dirs() {
    local file="$1"
    grep -i 'never access credential directories' "$file" \
        | sed 's/.*directories: *//' \
        | sed 's/^ *//;s/ *$//' \
        | tr -d '`'
}

# Extract the credential files line from a file.
# Matches "Never access credential files:" followed by a comma-separated list.
extract_credential_files() {
    local file="$1"
    grep -i 'never access credential files' "$file" \
        | sed 's/.*files: *//' \
        | sed 's/^ *//;s/ *$//' \
        | tr -d '`'
}

# Extract emoji unicode range from a perl one-liner in a file.
# Returns the character class contents between [ and ].
# Uses sed instead of grep -P for portability (Alpine/macOS lack grep -P).
extract_emoji_range() {
    local file="$1"
    sed -n 's/.*if(\/\[\(\\x{[^]]*\)\]\/.*/\1/p' "$file" | head -1
}

# Extract the tool config dirs bootstrap/symlinks.sh wires into the state
# volume: every _wire_tool_dir call's target plus the explicit gh block.
# Patterns use [$] (a literal $ via a bracket expression) rather than \$ so
# they match the literal "$HOME" text without tripping SC2016.
extract_state_links_bootstrap() {
    local file="$1"
    {
        grep -oE '_wire_tool_dir "[^"]+" "[$]HOME/[^"]+"' "$file" \
            | grep -oE '[$]HOME/[A-Za-z0-9._/-]+'
        grep -oE 'setup_volume_dir "[$]HOME/\.dotfiles-state/[^"]+" "[$]HOME/[^"]+"' "$file" \
            | sed -E 's/.* "([$]HOME[^"]+)"$/\1/'
    } | sort -u
}

# Extract the symlinks healed by shell/state-heal.sh (its `for link in` block).
extract_state_links_heal() {
    local file="$1"
    sed -n '/for link in/,/^    do$/p' "$file" \
        | grep -oE '[$]HOME/[A-Za-z0-9._/-]+' \
        | sort -u
}

# ============================================================================
# Instruction files under test
# ============================================================================

AGENTS_ROOT="$DOTFILES_DIR/AGENTS.md"
CLAUDE_ROOT="$DOTFILES_DIR/CLAUDE.md"
CLAUDE_GLOBAL="$DOTFILES_DIR/claude-code/CLAUDE.md"
CODEX_AGENTS="$DOTFILES_DIR/codex/AGENTS.md"
COPILOT_GLOBAL="$DOTFILES_DIR/copilot/copilot-instructions.md"
COPILOT_GITHUB="$DOTFILES_DIR/.github/copilot-instructions.md"

INSTRUCTION_FILES=(
    "$AGENTS_ROOT"
    "$CLAUDE_GLOBAL"
    "$CODEX_AGENTS"
    "$COPILOT_GLOBAL"
    "$COPILOT_GITHUB"
)

# The three globally-deployed files. The root AGENTS.md and
# .github/copilot-instructions.md are repo-scoped and carry no worktree rules.
GLOBAL_FILES=(
    "$CLAUDE_GLOBAL"
    "$CODEX_AGENTS"
    "$COPILOT_GLOBAL"
)

WORKTREE_FRAGMENT="$DOTFILES_DIR/agent-prompts/worktrees.md"

# The operational worktree rules are single-sourced in agent-prompts/. This
# guard is the deliberate exception: it stays inlined per tool because
# Codex and Copilot load shared fragments best-effort (no import mechanism),
# and a silently disabled gitleaks hook is not something to deliver on a
# best-effort basis. Keep the wording identical so drift is detectable.
# shellcheck disable=SC2016  # backticks are literal markdown, not a subshell
HOOKS_PATH_GUARD='- Never set repo-local `core.hooksPath`: it silently disables the global secret-scanning and commit-message hooks'

# ============================================================================
# Test Suite: Worktree Rules
# ============================================================================

test_hooks_path_guard_inlined() {
    for file in "${GLOBAL_FILES[@]}"; do
        local basename
        basename="$(basename "$(dirname "$file")")/$(basename "$file")"
        if grep -Fqx -e "$HOOKS_PATH_GUARD" "$file"; then
            test_pass "core.hooksPath guard inlined in $basename"
        else
            test_fail "core.hooksPath guard missing or reworded in $basename"
            test_info "Expected verbatim: $HOOKS_PATH_GUARD"
        fi
    done
}

test_worktree_fragment_single_sourced() {
    if [[ -f "$WORKTREE_FRAGMENT" ]]; then
        test_pass "agent-prompts/worktrees.md exists"
    else
        test_fail "agent-prompts/worktrees.md missing"
        return
    fi

    # Each tool must actually pull the fragment in, by whatever mechanism it
    # has: Claude via a native @import, Codex and Copilot via their
    # read-at-session-start list. A fragment nothing references is dead.
    local file basename
    for file in "${GLOBAL_FILES[@]}"; do
        basename="$(basename "$(dirname "$file")")/$(basename "$file")"
        if grep -q 'prompts/worktrees\.md' "$file"; then
            test_pass "Worktree fragment referenced by $basename"
        else
            test_fail "Worktree fragment not referenced by $basename"
        fi
    done

    # The rules must live in exactly one place: if a tool file still carries
    # the operational bullets, the single-sourcing has been undone.
    for file in "${GLOBAL_FILES[@]}"; do
        basename="$(basename "$(dirname "$file")")/$(basename "$file")"
        if grep -Fq -e '- One agent per worktree' "$file"; then
            test_fail "Operational worktree bullets re-inlined in $basename"
        else
            test_pass "Operational worktree bullets not duplicated in $basename"
        fi
    done
}

# ============================================================================
# Test Suite: Shared Prompt Fragments
# ============================================================================

STYLE_FRAGMENT="$DOTFILES_DIR/agent-prompts/writing-style.md"
ENG_FRAGMENT="$DOTFILES_DIR/agent-prompts/engineering-conventions.md"
FORGE_FRAGMENT="$DOTFILES_DIR/agent-prompts/forge.md"

# Anchors for the personal-process rules that must live in the shared
# fragments and only there: the handoff-report contract in writing-style,
# the pre-handoff comment sweep in engineering-conventions, the forge CLI
# and PR/MR description rules in forge.md. Repo-scoped instruction files
# describe the desired artifact, not the author's process, so the same
# anchors must not appear in them.
STYLE_ANCHOR='material gaps or risks'
ENG_ANCHOR='Before handoff, sweep'
# shellcheck disable=SC2016  # backticks are literal markdown, not a subshell
FORGE_CLI_ANCHOR='Prefer purpose-built `gh` and `glab` subcommands'
FORGE_DESC_ANCHOR='Describe the change in its final form'

test_shared_fragments_referenced() {
    local fragment name file basename
    for fragment in "$STYLE_FRAGMENT" "$ENG_FRAGMENT" "$FORGE_FRAGMENT"; do
        name="$(basename "$fragment")"
        if [[ -f "$fragment" ]]; then
            test_pass "agent-prompts/$name exists"
        else
            test_fail "agent-prompts/$name missing"
            continue
        fi

        for file in "${GLOBAL_FILES[@]}"; do
            basename="$(basename "$(dirname "$file")")/$(basename "$file")"
            if grep -q "prompts/$name" "$file"; then
                test_pass "$name referenced by $basename"
            else
                test_fail "$name not referenced by $basename"
            fi
        done
    done
}

test_personal_process_rules_in_fragments() {
    if grep -Fq -e "$STYLE_ANCHOR" "$STYLE_FRAGMENT"; then
        test_pass "Handoff report contract present in writing-style.md"
    else
        test_fail "Handoff report contract missing from writing-style.md"
    fi

    if grep -Fq -e "$ENG_ANCHOR" "$ENG_FRAGMENT"; then
        test_pass "Pre-handoff comment sweep present in engineering-conventions.md"
    else
        test_fail "Pre-handoff comment sweep missing from engineering-conventions.md"
    fi

    if grep -Fq -e "$FORGE_CLI_ANCHOR" "$FORGE_FRAGMENT"; then
        test_pass "Forge CLI subcommands-over-api rule present in forge.md"
    else
        test_fail "Forge CLI subcommands-over-api rule missing from forge.md"
    fi

    if grep -Fq -e "$FORGE_DESC_ANCHOR" "$FORGE_FRAGMENT"; then
        test_pass "PR/MR description rules present in forge.md"
    else
        test_fail "PR/MR description rules missing from forge.md"
    fi

    # forge.md is conditionally loaded; if its rules creep back into the
    # always-loaded engineering-conventions fragment, the extraction that
    # keeps them out of every session has been undone.
    local anchor
    for anchor in "$FORGE_CLI_ANCHOR" "$FORGE_DESC_ANCHOR"; do
        if grep -Fq -e "$anchor" "$ENG_FRAGMENT"; then
            test_fail "Forge rule re-inlined in engineering-conventions.md: $anchor"
        else
            test_pass "Forge rule not duplicated in engineering-conventions.md: $anchor"
        fi
    done
}

test_personal_process_rules_not_in_repo_files() {
    local file basename anchor
    for file in "$AGENTS_ROOT" "$CLAUDE_ROOT" "$COPILOT_GITHUB"; do
        basename="$(basename "$(dirname "$file")")/$(basename "$file")"
        # Guard first: grep on a missing file exits 2, which would make every
        # absence assertion below pass vacuously.
        if [[ ! -f "$file" ]]; then
            test_fail "Repo-scoped instruction file missing: $basename"
            continue
        fi
        for anchor in "$STYLE_ANCHOR" "$ENG_ANCHOR" "$FORGE_CLI_ANCHOR" "$FORGE_DESC_ANCHOR"; do
            if grep -Fq -e "$anchor" "$file"; then
                test_fail "Personal process rule duplicated in repo-scoped $basename: $anchor"
            else
                test_pass "No personal process rule in repo-scoped $basename: $anchor"
            fi
        done
    done
}

# ============================================================================
# Test Suite: Credential Directory Deny Lists
# ============================================================================

test_credential_dirs_present() {
    for file in "${INSTRUCTION_FILES[@]}"; do
        local basename
        basename="$(basename "$(dirname "$file")")/$(basename "$file")"
        local dirs
        dirs=$(extract_credential_dirs "$file")
        if [[ -n "$dirs" ]]; then
            test_pass "Credential directories found in $basename"
        else
            test_fail "Credential directories missing from $basename"
        fi
    done
}

test_credential_dirs_match() {
    local reference
    reference=$(extract_credential_dirs "$AGENTS_ROOT")

    for file in "${INSTRUCTION_FILES[@]}"; do
        [[ "$file" == "$AGENTS_ROOT" ]] && continue
        local basename
        basename="$(basename "$(dirname "$file")")/$(basename "$file")"
        local dirs
        dirs=$(extract_credential_dirs "$file")
        if [[ "$dirs" == "$reference" ]]; then
            test_pass "Credential directories match root AGENTS.md in $basename"
        else
            test_fail "Credential directories differ in $basename"
            test_info "Expected: $reference"
            test_info "Got:      $dirs"
        fi
    done
}

# ============================================================================
# Test Suite: Credential File Deny Lists
# ============================================================================

test_credential_files_present() {
    for file in "${INSTRUCTION_FILES[@]}"; do
        local basename
        basename="$(basename "$(dirname "$file")")/$(basename "$file")"
        local files
        files=$(extract_credential_files "$file")
        if [[ -n "$files" ]]; then
            test_pass "Credential file patterns found in $basename"
        else
            test_fail "Credential file patterns missing from $basename"
        fi
    done
}

test_credential_files_match() {
    local reference
    reference=$(extract_credential_files "$AGENTS_ROOT")

    for file in "${INSTRUCTION_FILES[@]}"; do
        [[ "$file" == "$AGENTS_ROOT" ]] && continue
        local basename
        basename="$(basename "$(dirname "$file")")/$(basename "$file")"
        local files
        files=$(extract_credential_files "$file")
        if [[ "$files" == "$reference" ]]; then
            test_pass "Credential file patterns match root AGENTS.md in $basename"
        else
            test_fail "Credential file patterns differ in $basename"
            test_info "Expected: $reference"
            test_info "Got:      $files"
        fi
    done
}

# ============================================================================
# Test Suite: Emoji Detection Pattern Consistency
# ============================================================================

test_emoji_range_shared_vs_commit_msg() {
    local shared_file="$DOTFILES_DIR/agent-hooks/shared-patterns.sh"
    local commit_msg="$DOTFILES_DIR/git/hooks/commit-msg"

    if [[ ! -f "$shared_file" ]]; then
        test_info "shared-patterns.sh not present (PR #39 not yet merged), skipping"
        return
    fi

    local shared_range
    shared_range=$(extract_emoji_range "$shared_file")
    local commit_range
    commit_range=$(extract_emoji_range "$commit_msg")

    if [[ -z "$shared_range" ]]; then
        test_fail "Could not extract emoji range from shared-patterns.sh"
        return
    fi
    if [[ -z "$commit_range" ]]; then
        # commit-msg may source shared-patterns.sh with no inline fallback
        test_info "No inline emoji range in commit-msg (uses shared-patterns.sh only)"
        return
    fi

    if [[ "$shared_range" == "$commit_range" ]]; then
        test_pass "Emoji unicode ranges match between shared-patterns.sh and commit-msg"
    else
        test_fail "Emoji unicode ranges differ"
        test_info "shared-patterns.sh: $shared_range"
        test_info "commit-msg:         $commit_range"
    fi
}

# ============================================================================
# Test Suite: Attribution Regex Consistency
# ============================================================================

test_attribution_regex_shared_vs_commit_msg() {
    local shared_file="$DOTFILES_DIR/agent-hooks/shared-patterns.sh"
    local commit_msg="$DOTFILES_DIR/git/hooks/commit-msg"

    if [[ ! -f "$shared_file" ]]; then
        test_info "shared-patterns.sh not present (PR #39 not yet merged), skipping"
        return
    fi

    # Extract grep patterns scoped to has_ai_attribution function in shared-patterns.sh
    local shared_patterns
    shared_patterns=$(sed -n '/^has_ai_attribution/,/^}/p' "$shared_file" \
        | grep -E "grep -qiE" | sed "s/.*grep -qiE '//;s/'[^']*$//" | sort)

    # Extract attribution patterns from commit-msg. Post-PR#39: inside _check_attribution.
    # Pre-PR#39: inline at top level. Match all attribution-related grep -qiE lines.
    local commit_patterns
    commit_patterns=$(grep -E "grep -qiE '.*(claude|anthropic|gpt)" "$commit_msg" \
        | sed "s/.*grep -qiE '//;s/'[^']*$//" | sort)

    if [[ -z "$shared_patterns" ]]; then
        test_fail "Could not extract attribution patterns from shared-patterns.sh"
        return
    fi
    if [[ -z "$commit_patterns" ]]; then
        # commit-msg may source shared-patterns.sh with no inline fallback
        test_info "No inline attribution patterns in commit-msg (uses shared-patterns.sh only)"
        return
    fi

    if [[ "$shared_patterns" == "$commit_patterns" ]]; then
        test_pass "Attribution regex patterns match between shared-patterns.sh and commit-msg"
    else
        test_fail "Attribution regex patterns differ"
        test_info "shared-patterns.sh patterns: $(echo "$shared_patterns" | tr '\n' ' ')"
        test_info "commit-msg patterns:         $(echo "$commit_patterns" | tr '\n' ' ')"
    fi
}

# ============================================================================
# Test Suite: Shared Agent Hook Wrappers
# ============================================================================

test_agent_hook_wrappers_point_to_shared_dir() {
    local hook tool wrapper
    for hook in pre-security.sh pre-code-no-emoji.sh; do
        if [[ -x "$DOTFILES_DIR/agent-hooks/$hook" ]]; then
            test_pass "Shared hook is executable: $hook"
        else
            test_fail "Shared hook missing or not executable: $hook"
        fi

        for tool in claude-code codex; do
            wrapper="$DOTFILES_DIR/$tool/hooks/$hook"
            if [[ ! -x "$wrapper" ]]; then
                test_fail "$tool wrapper missing or not executable: $hook"
            elif grep -q '\.agent-hooks' "$wrapper" && grep -q '../../agent-hooks' "$wrapper"; then
                test_pass "$tool wrapper resolves shared hook: $hook"
            else
                test_fail "$tool wrapper does not resolve shared hook: $hook"
            fi
        done
    done
}

test_codex_wrappers_do_not_depend_on_claude_hooks() {
    local hook wrapper
    for hook in pre-security.sh pre-code-no-emoji.sh; do
        wrapper="$DOTFILES_DIR/codex/hooks/$hook"
        if grep -q '\.claude/hooks' "$wrapper"; then
            test_fail "Codex wrapper depends on Claude hook path: $hook"
        else
            test_pass "Codex wrapper is independent of Claude hook path: $hook"
        fi
    done
}

test_codex_wrappers_do_not_emit_ask_decisions() {
    local tmpdir wrapper output decision
    tmpdir="$(mktemp -d)"

    # Currently only pre-security.sh does the ask->deny mapping. Keep the
    # loop form so adding a second wrapper is a one-line change.
    # shellcheck disable=SC2043
    for hook in pre-security.sh; do
        cat > "$tmpdir/$hook" <<'SH'
#!/usr/bin/env bash
read -r _input
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"test"}}'
SH
        chmod +x "$tmpdir/$hook"

        wrapper="$DOTFILES_DIR/codex/hooks/$hook"
        output=$(DOTFILES_AGENT_HOOKS_DIR="$tmpdir" "$wrapper" <<< '{}')
        decision=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecision')

        if [[ "$decision" == "deny" ]]; then
            test_pass "Codex wrapper maps ask to deny: $hook"
        else
            test_fail "Codex wrapper emitted unsupported decision for $hook"
            test_info "Output: $output"
        fi
    done

    rm -rf "$tmpdir"
}

test_codex_wrappers_fail_closed_on_hook_errors() {
    local tmpdir wrapper output decision
    tmpdir="$(mktemp -d)"

    for hook in pre-security.sh pre-code-no-emoji.sh; do
        cat > "$tmpdir/$hook" <<'SH'
#!/usr/bin/env bash
exit 1
SH
        chmod +x "$tmpdir/$hook"

        wrapper="$DOTFILES_DIR/codex/hooks/$hook"
        output=$(DOTFILES_AGENT_HOOKS_DIR="$tmpdir" "$wrapper" <<< '{}')
        decision=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecision')

        if [[ "$decision" == "deny" ]]; then
            test_pass "Codex wrapper fails closed: $hook"
        else
            test_fail "Codex wrapper did not fail closed for $hook"
            test_info "Output: $output"
        fi
    done

    rm -rf "$tmpdir"
}

# ============================================================================
# Test Suite: MCP Guidance Presence
# ============================================================================

test_mcp_guidance_present() {
    for file in "${INSTRUCTION_FILES[@]}"; do
        local basename
        basename="$(basename "$(dirname "$file")")/$(basename "$file")"
        if grep -qi 'MCP' "$file"; then
            test_pass "MCP guidance found in $basename"
        else
            test_fail "MCP guidance missing from $basename"
        fi
    done
}

# ============================================================================
# Test Suite: Command and Skill Frontmatter
# ============================================================================

# Emit the frontmatter of a markdown file -- the lines between the leading
# "---" and the next one -- or nothing when the file has no frontmatter block.
extract_frontmatter() {
    awk 'NR == 1 && $0 == "---" { inside = 1; next }
         inside && $0 == "---" { exit }
         inside { print }' "$1"
}

# Claude Code reads description, argument-hint, and allowed-tools from the
# frontmatter block. A missing or unclosed block drops all three silently.
test_command_frontmatter_present() {
    local missing=()
    local file
    for file in "$DOTFILES_DIR"/claude-code/commands/*.md; do
        [[ -f "$file" ]] || continue
        if [[ -z "$(extract_frontmatter "$file")" ]]; then
            missing+=("$(basename "$file")")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        test_pass "All command files open with a frontmatter block"
    else
        test_fail "Command files with missing or unclosed frontmatter: ${missing[*]}"
    fi
}

# The skill inventory is the directory itself: deployment (symlinks.sh) and
# drift checking (prompt-drift.sh) both glob agent-skills/*, so validating a
# hand-maintained name list here is a cache of the filesystem that drifts.
test_shared_skill_frontmatter_present() {
    local missing=() invalid=() skill_dir skill file frontmatter count=0
    for skill_dir in "$DOTFILES_DIR"/agent-skills/*/; do
        skill=$(basename "$skill_dir")
        file="$skill_dir/SKILL.md"
        count=$((count + 1))
        if [[ ! -f "$file" ]]; then
            missing+=("$skill")
            continue
        fi
        frontmatter=$(extract_frontmatter "$file")
        if ! printf '%s\n' "$frontmatter" | grep -Fqx "name: $skill" \
            || ! printf '%s\n' "$frontmatter" | grep -q '^description:'; then
            invalid+=("$skill")
        fi
    done

    if [[ $count -eq 0 ]]; then
        test_fail "No shared Agent Skills found under agent-skills/"
    elif [[ ${#missing[@]} -eq 0 && ${#invalid[@]} -eq 0 ]]; then
        test_pass "All $count shared Agent Skills have portable frontmatter"
    else
        [[ ${#missing[@]} -eq 0 ]] || test_fail "Shared Agent Skill directories without SKILL.md: ${missing[*]}"
        [[ ${#invalid[@]} -eq 0 ]] || test_fail "Invalid shared Agent Skill frontmatter: ${invalid[*]}"
    fi
}

# The skill counts in README.md and docs/agentic-tooling.md are hand-edited
# table cells with nothing else tying them to the directory they describe.
test_shared_skill_count_documented() {
    local actual readme docs stale=()
    actual=$(find "$DOTFILES_DIR/agent-skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d '[:space:]')
    readme=$(sed -n 's/^| Shared Agent Skills *| *\([0-9][0-9]*\) .*/\1/p' "$DOTFILES_DIR/README.md")
    docs=$(sed -n 's/^| Shared skills *| *\([0-9][0-9]*\) .*/\1/p' "$DOTFILES_DIR/docs/agentic-tooling.md")

    [[ "$readme" == "$actual" ]] || stale+=("README.md says '${readme:-nothing}'")
    [[ "$docs" == "$actual" ]] || stale+=("docs/agentic-tooling.md says '${docs:-nothing}'")
    if [[ ${#stale[@]} -eq 0 ]]; then
        test_pass "Documented shared skill counts match the $actual skill directories"
    else
        test_fail "Shared skill count is $actual but ${stale[*]}"
    fi
}

test_shared_skills_are_platform_neutral() {
    local hits
    # shellcheck disable=SC2016  # Match literal skill placeholders and paths.
    hits=$(grep -RInE '\$ARGUMENTS|\$[0-9]|~/\.(claude|codex)/' \
        "$DOTFILES_DIR/agent-skills" || true)
    if [[ -z "$hits" ]]; then
        test_pass "Shared Agent Skills contain no Claude- or Codex-specific paths or arguments"
    else
        test_fail "Shared Agent Skills contain platform-specific content"
        test_info "$hits"
    fi
}

# A permission rule's parenthesised content is one prefix pattern, not a list.
# Bash(git log:*, git tag:*) therefore matches nothing and every prefix in the
# group is denied; each one needs its own Bash(...) entry. Verified against a
# live session -- the packed form returns "This command requires approval".
test_no_packed_permission_rules() {
    local packed=()
    local file line
    for file in "$DOTFILES_DIR"/claude-code/commands/*.md; do
        [[ -f "$file" ]] || continue
        line=$(extract_frontmatter "$file" | grep '^allowed-tools:' || true)
        [[ -n "$line" ]] || continue
        if printf '%s\n' "$line" | grep -Eq '[A-Za-z_]+\([^)]*,[^)]*\)'; then
            packed+=("$(basename "$file")")
        fi
    done

    if [[ ${#packed[@]} -eq 0 ]]; then
        test_pass "No packed Tool(a, b) permission rules in command frontmatter"
    else
        test_fail "Packed permission rules, split into separate entries: ${packed[*]}"
    fi
}

# An unquoted value opening with "[" is a YAML flow sequence, so
# "[from-tag] [to-tag]" is two sequences with no separator and fails a strict
# parse. Claude Code's own parser is lenient, which is what lets this rot go
# unnoticed until some other tool reads the file as YAML.
test_frontmatter_bracket_values_parse() {
    local bad=()
    local file line value
    for file in "$DOTFILES_DIR"/claude-code/commands/*.md; do
        [[ -f "$file" ]] || continue
        while IFS= read -r line; do
            [[ "$line" =~ ^[a-zA-Z_-]+:[[:space:]]*(.*)$ ]] || continue
            value="${BASH_REMATCH[1]}"
            [[ "$value" == \[* ]] || continue
            if [[ ! "$value" =~ ^\[[^][]*\]$ ]]; then
                bad+=("$(basename "$file"): $line")
            fi
        done < <(extract_frontmatter "$file")
    done

    if [[ ${#bad[@]} -eq 0 ]]; then
        test_pass "Bracketed frontmatter values are valid YAML flow sequences"
    else
        test_fail "Bracketed values need quoting: ${bad[*]}"
    fi
}

# ============================================================================
# Test Suite: Dotfiles State Self-Heal Link List
# ============================================================================

# shell/state-heal.sh hardcodes the symlinks it heals and relies on a comment
# to stay in sync with bootstrap/symlinks.sh. This enforces that invariant: a
# tool dir wired by bootstrap must also be covered by the self-heal guard.
test_state_heal_links_match() {
    local symlinks_sh="$DOTFILES_DIR/bootstrap/symlinks.sh"
    local state_heal_sh="$DOTFILES_DIR/shell/state-heal.sh"
    local bootstrap_links heal_links
    bootstrap_links=$(extract_state_links_bootstrap "$symlinks_sh")
    heal_links=$(extract_state_links_heal "$state_heal_sh")

    if [[ "$bootstrap_links" == "$heal_links" ]]; then
        test_pass "state-heal.sh link list matches bootstrap/symlinks.sh"
    else
        test_fail "state-heal.sh link list has drifted from bootstrap/symlinks.sh"
        test_info "bootstrap/symlinks.sh: $(echo "$bootstrap_links" | tr '\n' ' ')"
        test_info "shell/state-heal.sh:   $(echo "$heal_links" | tr '\n' ' ')"
    fi
}

# ============================================================================
# Minimum git version
# ============================================================================

# bootstrap/versions.sh is the canonical floor. bin/wt and
# claude-code/hooks/worktree-create.sh deploy as standalone scripts that
# cannot source it at runtime, so they inline the value; keep the copies
# from drifting.
test_min_git_floor_matches() {
    local canonical wt_floor wtc_floor
    canonical=$(sed -n 's/^export DOTFILES_MIN_GIT="\(.*\)"$/\1/p' "$DOTFILES_DIR/bootstrap/versions.sh")
    if [[ -z "$canonical" ]]; then
        test_fail "bootstrap/versions.sh defines DOTFILES_MIN_GIT"
        return
    fi
    test_pass "bootstrap/versions.sh defines DOTFILES_MIN_GIT ($canonical)"

    wt_floor=$(sed -n 's/^WT_MIN_GIT="\(.*\)"$/\1/p' "$DOTFILES_DIR/bin/wt")
    assert_equals "$canonical" "$wt_floor" \
        "bin/wt WT_MIN_GIT matches bootstrap/versions.sh"

    wtc_floor=$(sed -n 's/.*local rel="" min_git="\(.*\)"$/\1/p' \
        "$DOTFILES_DIR/claude-code/hooks/worktree-create.sh")
    assert_equals "$canonical" "$wtc_floor" \
        "worktree-create.sh min_git matches bootstrap/versions.sh"
}

# ============================================================================
# Run all tests
# ============================================================================

main() {
    echo -e "${CYAN}Starting Consistency Tests${NC}\n"

    test_suite "Worktree Rules"
    test_hooks_path_guard_inlined
    test_worktree_fragment_single_sourced

    test_suite "Shared Prompt Fragments"
    test_shared_fragments_referenced
    test_personal_process_rules_in_fragments
    test_personal_process_rules_not_in_repo_files

    test_suite "Credential Directory Deny Lists"
    test_credential_dirs_present
    test_credential_dirs_match

    test_suite "Credential File Pattern Deny Lists"
    test_credential_files_present
    test_credential_files_match

    test_suite "Emoji Detection Patterns"
    test_emoji_range_shared_vs_commit_msg

    test_suite "Attribution Regex Patterns"
    test_attribution_regex_shared_vs_commit_msg

    test_suite "Shared Agent Hook Wrappers"
    test_agent_hook_wrappers_point_to_shared_dir
    test_codex_wrappers_do_not_depend_on_claude_hooks
    test_codex_wrappers_do_not_emit_ask_decisions
    test_codex_wrappers_fail_closed_on_hook_errors

    test_suite "MCP Guidance"
    test_mcp_guidance_present

    test_suite "Command Frontmatter"
    test_command_frontmatter_present
    test_no_packed_permission_rules
    test_frontmatter_bracket_values_parse

    test_suite "Shared Agent Skills"
    test_shared_skill_frontmatter_present
    test_shared_skill_count_documented
    test_shared_skills_are_platform_neutral

    test_suite "Dotfiles State Self-Heal Link List"
    test_state_heal_links_match

    test_suite "Minimum Git Version"
    test_min_git_floor_matches

    print_test_summary
}

main
