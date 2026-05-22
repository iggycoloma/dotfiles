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
    local shared_file="$DOTFILES_DIR/claude-code/hooks/shared-patterns.sh"
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
    local shared_file="$DOTFILES_DIR/claude-code/hooks/shared-patterns.sh"
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
# Run all tests
# ============================================================================

main() {
    echo -e "${CYAN}Starting Consistency Tests${NC}\n"

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

    test_suite "MCP Guidance"
    test_mcp_guidance_present

    test_suite "Dotfiles State Self-Heal Link List"
    test_state_heal_links_match

    print_test_summary
}

main
