#!/usr/bin/env bash
# Unit tests for dotfiles bootstrap functions
# Tests individual functions in isolation

# Note: We don't use 'set -e' because test framework handles failures
set +e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# Preserve real path for tests that run after setup_test_env changes DOTFILES_DIR
REAL_DOTFILES_DIR="$DOTFILES_DIR"

# Source test framework
source "$SCRIPT_DIR/test-framework.sh"

# Source bootstrap scripts to test
# Note: Bootstrap scripts have 'set -e' which we need to override
source "$DOTFILES_DIR/bootstrap/detect.sh" 2>/dev/null
source "$DOTFILES_DIR/bootstrap/symlinks.sh" 2>/dev/null

# Re-disable set -e after sourcing (bootstrap scripts enable it)
set +e

#
# Test Suite: create_symlink function
#

test_symlink_source_missing() {
    setup_test_env

    local source="$TEST_TEMP_DIR/dotfiles/nonexistent"
    local target="$TEST_TEMP_DIR/home/.bashrc"

    # Should fail when source doesn't exist
    if create_symlink "$source" "$target" 2>/dev/null; then
        test_fail "create_symlink should fail with missing source"
    else
        test_pass "create_symlink fails with missing source"
    fi

    assert_file_not_exists "$target" "Target should not be created"

    teardown_test_env
}

test_symlink_creates_new_link() {
    setup_test_env

    local source="$TEST_TEMP_DIR/dotfiles/.bashrc"
    local target="$TEST_TEMP_DIR/home/.bashrc"

    mock_file "$source" "# bashrc content"

    create_symlink "$source" "$target" &>/dev/null

    assert_is_symlink "$target" "Should create symlink"
    assert_symlink "$target" "$source" "Symlink should point to correct source"

    teardown_test_env
}

test_symlink_replaces_existing_symlink() {
    setup_test_env

    local old_source="$TEST_TEMP_DIR/dotfiles/old/.bashrc"
    local new_source="$TEST_TEMP_DIR/dotfiles/new/.bashrc"
    local target="$TEST_TEMP_DIR/home/.bashrc"

    mock_file "$old_source" "# old"
    mock_file "$new_source" "# new"
    mock_symlink "$target" "$old_source"

    create_symlink "$new_source" "$target" &>/dev/null

    assert_is_symlink "$target" "Should still be a symlink"
    assert_symlink "$target" "$new_source" "Symlink should point to new source"

    teardown_test_env
}

test_symlink_backs_up_real_file() {
    setup_test_env

    local source="$TEST_TEMP_DIR/dotfiles/.bashrc"
    local target="$TEST_TEMP_DIR/home/.bashrc"
    local content="# original content"

    mock_file "$source" "# new content"
    mock_file "$target" "$content"

    # Note: BACKUP_DIR is set by symlinks.sh based on date
    # We can't predict it, but we can verify target becomes a symlink
    create_symlink "$source" "$target" &>/dev/null

    assert_is_symlink "$target" "Should replace file with symlink"
    assert_symlink "$target" "$source" "Symlink should point to source"

    teardown_test_env
}

test_symlink_creates_parent_directories() {
    setup_test_env

    local source="$TEST_TEMP_DIR/dotfiles/git/.gitconfig"
    local target="$TEST_TEMP_DIR/home/.config/git/config"

    mock_file "$source" "# git config"

    # Parent directory should not exist yet
    assert_file_not_exists "$TEST_TEMP_DIR/home/.config" "Parent dir should not exist yet"

    create_symlink "$source" "$target" &>/dev/null

    assert_dir_exists "$TEST_TEMP_DIR/home/.config/git" "Parent directories should be created"
    assert_symlink "$target" "$source" "Symlink should be created"

    teardown_test_env
}

#
# Test Suite: backup_if_exists function
#

test_backup_real_file() {
    setup_test_env

    local target="$TEST_TEMP_DIR/home/.bashrc"
    local content="# original content"
    mock_file "$target" "$content"

    # backup_if_exists will create BACKUP_DIR
    backup_if_exists "$target" &>/dev/null

    assert_file_not_exists "$target" "Original file should be removed"
    # Backup directory is date-stamped, we can't easily verify exact location
    # But the function should have succeeded

    teardown_test_env
}

test_backup_removes_symlink() {
    setup_test_env

    local source="$TEST_TEMP_DIR/dotfiles/.bashrc"
    local target="$TEST_TEMP_DIR/home/.bashrc"

    mock_file "$source" "# content"
    mock_symlink "$target" "$source"

    assert_is_symlink "$target" "Target should be a symlink"

    backup_if_exists "$target" &>/dev/null

    assert_file_not_exists "$target" "Symlink should be removed"

    teardown_test_env
}

test_backup_nothing_exists() {
    setup_test_env

    local target="$TEST_TEMP_DIR/home/.bashrc"

    # Should not fail when nothing exists
    if backup_if_exists "$target" &>/dev/null; then
        test_pass "backup_if_exists succeeds when nothing exists"
    else
        test_fail "backup_if_exists should succeed when nothing exists"
    fi

    teardown_test_env
}

test_backup_directory() {
    setup_test_env

    local target="$TEST_TEMP_DIR/home/.config"
    mock_dir "$target"
    mock_file "$target/file.txt" "content"

    backup_if_exists "$target" &>/dev/null

    assert_file_not_exists "$target" "Directory should be removed"

    teardown_test_env
}

#
# Test Suite: is_devcontainer function
#

test_devcontainer_remote_containers() {
    # Save original value
    local original="${REMOTE_CONTAINERS:-}"

    export REMOTE_CONTAINERS="true"

    if is_devcontainer; then
        test_pass "is_devcontainer returns 0 with REMOTE_CONTAINERS=true"
    else
        test_fail "is_devcontainer should return 0 with REMOTE_CONTAINERS=true"
    fi

    # Restore
    if [[ -n "$original" ]]; then
        export REMOTE_CONTAINERS="$original"
    else
        unset REMOTE_CONTAINERS
    fi
}

test_devcontainer_codespaces() {
    # Save original value
    local original="${CODESPACES:-}"

    export CODESPACES="true"

    if is_devcontainer; then
        test_pass "is_devcontainer returns 0 with CODESPACES=true"
    else
        test_fail "is_devcontainer should return 0 with CODESPACES=true"
    fi

    # Restore
    if [[ -n "$original" ]]; then
        export CODESPACES="$original"
    else
        unset CODESPACES
    fi
}

test_devcontainer_neither_set() {
    # Save original values
    local original_rc="${REMOTE_CONTAINERS:-}"
    local original_cs="${CODESPACES:-}"

    unset REMOTE_CONTAINERS
    unset CODESPACES

    if is_devcontainer; then
        test_fail "is_devcontainer should return 1 with neither variable set"
    else
        test_pass "is_devcontainer returns 1 with neither variable set"
    fi

    # Restore
    [[ -n "$original_rc" ]] && export REMOTE_CONTAINERS="$original_rc"
    [[ -n "$original_cs" ]] && export CODESPACES="$original_cs"
}

#
# Test Suite: detect_environment function
#

test_detect_codespaces() {
    local original="${CODESPACES:-}"
    export CODESPACES="true"

    local result=$(detect_environment)
    assert_equals "codespaces" "$result" "Should detect Codespaces"

    # Restore original value
    if [[ -n "$original" ]]; then
        export CODESPACES="$original"
    else
        unset CODESPACES
    fi
}

test_detect_devcontainer() {
    local original_cs="${CODESPACES:-}"
    local original_rc="${REMOTE_CONTAINERS:-}"

    unset CODESPACES
    export REMOTE_CONTAINERS="true"

    local result=$(detect_environment)
    assert_equals "devcontainer" "$result" "Should detect devcontainer"

    # Restore original values
    if [[ -n "$original_cs" ]]; then
        export CODESPACES="$original_cs"
    fi
    if [[ -n "$original_rc" ]]; then
        export REMOTE_CONTAINERS="$original_rc"
    else
        unset REMOTE_CONTAINERS
    fi
}

test_detect_local() {
    local original_cs="${CODESPACES:-}"
    local original_rc="${REMOTE_CONTAINERS:-}"
    local original_ssh="${SSH_CONNECTION:-}"

    unset CODESPACES
    unset REMOTE_CONTAINERS
    unset SSH_CONNECTION

    local result=$(detect_environment)
    assert_equals "local" "$result" "Should detect local environment"

    # Restore original values
    if [[ -n "$original_cs" ]]; then
        export CODESPACES="$original_cs"
    fi
    if [[ -n "$original_rc" ]]; then
        export REMOTE_CONTAINERS="$original_rc"
    fi
    if [[ -n "$original_ssh" ]]; then
        export SSH_CONNECTION="$original_ssh"
    fi
}

#
# Test Suite: Logging Module
#

test_logging_sources_without_error() {
    (
        unset _DOTFILES_LOGGING_LOADED
        source "$REAL_DOTFILES_DIR/bootstrap/logging.sh"
    )
    local rc=$?
    assert_equals "0" "$rc" "logging.sh sources without error"
}

test_logging_double_source_idempotent() {
    local output
    output=$(
        unset _DOTFILES_LOGGING_LOADED
        source "$REAL_DOTFILES_DIR/bootstrap/logging.sh"
        source "$REAL_DOTFILES_DIR/bootstrap/logging.sh"
        type log_info >/dev/null 2>&1 && echo "ok"
    )
    assert_equals "ok" "$output" "Sourcing logging.sh twice is idempotent"
}

test_logging_output_format() {
    local output
    output=$(
        unset _DOTFILES_LOGGING_LOADED
        source "$REAL_DOTFILES_DIR/bootstrap/logging.sh"
        log_info "test message"
    )
    assert_contains "$output" "==>" "log_info output contains ==>"
    assert_contains "$output" "test message" "log_info output contains message"
}

#
# Test Suite: Shell Config
#

test_path_no_duplicates() {
    local output
    output=$(
        # Preserve existing PATH so grep/tr remain available
        export HOME="/tmp/test_home_$$"
        source "$REAL_DOTFILES_DIR/shell/exports.sh" 2>/dev/null
        source "$REAL_DOTFILES_DIR/shell/exports.sh" 2>/dev/null
        echo "$PATH" | tr ':' '\n' | grep -c "/test_home_.*/\.local/bin"
    )
    assert_equals "1" "$output" "PATH contains .local/bin exactly once after double source"
}

test_completion_no_local_at_file_scope() {
    # Verify that completion.sh does not use 'local' outside of a function
    # The zsh_config line should not have 'local' keyword
    if grep -n '^\s*local ' "$REAL_DOTFILES_DIR/shell/completion.sh" | grep -v '^\s*#' | while read -r line; do
        local lineno="${line%%:*}"
        # Check if this line is inside a function by looking for preceding function declaration
        local in_function
        in_function=$(head -n "$lineno" "$REAL_DOTFILES_DIR/shell/completion.sh" | grep -c '^\s*\(function \)\?\w\+\s*()')
        if [[ "$in_function" -eq 0 ]]; then
            echo "FOUND: $line"
            return 1
        fi
    done; then
        test_pass "No 'local' at file scope in completion.sh"
    else
        test_fail "Found 'local' at file scope in completion.sh"
    fi
}

#
# Test Suite: Installation Toggle Gates
#

# Helper: set up a minimal dotfiles tree that create_symlinks expects
_setup_toggle_env() {
    setup_test_env

    # Minimal shell configs (required by create_symlinks)
    for f in .bashrc .bash_profile .zshrc .zprofile; do
        mock_file "$TEST_TEMP_DIR/dotfiles/shell/$f" "# $f"
    done

    # Git configs
    mock_file "$TEST_TEMP_DIR/dotfiles/git/.gitconfig" "# git"
    mock_file "$TEST_TEMP_DIR/dotfiles/git/.gitignore_global" "# ignore"
    mock_file "$TEST_TEMP_DIR/dotfiles/git/.gitmessage" "# message"
    mkdir -p "$TEST_TEMP_DIR/dotfiles/git/hooks"
    echo '#!/bin/sh' > "$TEST_TEMP_DIR/dotfiles/git/hooks/commit-msg"
    chmod +x "$TEST_TEMP_DIR/dotfiles/git/hooks/commit-msg"

    # Claude Code config
    mkdir -p "$TEST_TEMP_DIR/dotfiles/claude-code/hooks"
    mock_file "$TEST_TEMP_DIR/dotfiles/claude-code/CLAUDE.md" "# claude"
    mock_file "$TEST_TEMP_DIR/dotfiles/claude-code/settings.json" "{}"
    mock_file "$TEST_TEMP_DIR/dotfiles/claude-code/statusline.sh" "#!/bin/sh"

    # Codex config
    mkdir -p "$TEST_TEMP_DIR/dotfiles/codex/hooks"
    mock_file "$TEST_TEMP_DIR/dotfiles/codex/AGENTS.md" "# codex"

    # Ensure XDG config dir
    mkdir -p "$TEST_TEMP_DIR/home/.config/git"
}

test_toggle_no_ai_tools_skips_claude_config() {
    _setup_toggle_env
    export DOTFILES_NO_AI_TOOLS=1

    create_symlinks &>/dev/null

    assert_file_not_exists "$TEST_TEMP_DIR/home/.claude/CLAUDE.md" \
        "DOTFILES_NO_AI_TOOLS=1 should skip Claude Code config"

    unset DOTFILES_NO_AI_TOOLS
    teardown_test_env
}

test_toggle_no_ai_tools_skips_codex_config() {
    _setup_toggle_env
    export DOTFILES_NO_AI_TOOLS=1

    create_symlinks &>/dev/null

    assert_file_not_exists "$TEST_TEMP_DIR/home/.codex/AGENTS.md" \
        "DOTFILES_NO_AI_TOOLS=1 should skip Codex config"

    unset DOTFILES_NO_AI_TOOLS
    teardown_test_env
}

test_toggle_no_git_hooks_skips_hooks() {
    _setup_toggle_env
    export DOTFILES_NO_GIT_HOOKS=1

    create_symlinks &>/dev/null

    if [[ -L "$TEST_TEMP_DIR/home/.config/git/hooks" ]]; then
        test_fail "DOTFILES_NO_GIT_HOOKS=1 should skip git hooks symlink"
    else
        test_pass "DOTFILES_NO_GIT_HOOKS=1 skips git hooks symlink"
    fi

    unset DOTFILES_NO_GIT_HOOKS
    teardown_test_env
}

test_toggle_default_installs_all() {
    _setup_toggle_env
    # Ensure toggles are unset
    unset DOTFILES_NO_AI_TOOLS 2>/dev/null || true
    unset DOTFILES_NO_GIT_HOOKS 2>/dev/null || true

    create_symlinks &>/dev/null

    # Claude config should be deployed (as symlink in local mode)
    assert_file_exists "$TEST_TEMP_DIR/home/.claude/CLAUDE.md" \
        "Default (no toggles) should deploy Claude Code config"

    # Git hooks should be symlinked
    assert_is_symlink "$TEST_TEMP_DIR/home/.config/git/hooks" \
        "Default (no toggles) should symlink git hooks"

    teardown_test_env
}

test_toggle_no_ai_tools_log_message() {
    _setup_toggle_env
    export DOTFILES_NO_AI_TOOLS=1

    local output
    output=$(create_symlinks 2>&1)

    assert_contains "$output" "DOTFILES_NO_AI_TOOLS=1" \
        "Should log toggle skip message for AI tools"

    unset DOTFILES_NO_AI_TOOLS
    teardown_test_env
}

#
# Test Suite: State Persistence Tier Detection
#

# -- Detection tests (pure, no side effects) --

test_detect_state_tier_volume() {
    setup_test_env
    mkdir -p "$TEST_TEMP_DIR/home/.dotfiles-state"

    detect_state_tier

    assert_equals "volume" "$STATE_TIER" "Real directory should be detected as volume tier"
    assert_equals "$TEST_TEMP_DIR/home/.dotfiles-state" "$STATE_PATH" "Volume path should be ~/.dotfiles-state"

    teardown_test_env
}

test_detect_state_tier_symlink_not_volume() {
    setup_test_env
    mkdir -p "$TEST_TEMP_DIR/workspace-state"
    ln -snf "$TEST_TEMP_DIR/workspace-state" "$TEST_TEMP_DIR/home/.dotfiles-state"

    export CODESPACES=true
    detect_state_tier

    assert_not_equals "volume" "$STATE_TIER" "Symlink should NOT be detected as volume tier"

    unset CODESPACES
    teardown_test_env
}

test_detect_state_tier_codespaces() {
    setup_test_env
    export CODESPACES=true

    detect_state_tier

    assert_equals "codespaces" "$STATE_TIER" "Should detect codespaces tier"
    assert_equals "/workspaces/.codespaces/.persistedshare/dotfiles-state" "$STATE_PATH" \
        "Should set codespaces path"

    unset CODESPACES
    teardown_test_env
}

test_detect_state_tier_ephemeral() {
    setup_test_env
    unset CODESPACES 2>/dev/null || true

    detect_state_tier

    assert_equals "ephemeral" "$STATE_TIER" "Should fall back to ephemeral tier"
    assert_equals "$TEST_TEMP_DIR/home/.dotfiles-state" "$STATE_PATH" \
        "Ephemeral path should be ~/.dotfiles-state"

    teardown_test_env
}

# -- Setup tests (side effects: dirs, symlinks, permissions) --

test_setup_state_ephemeral_creates_dir() {
    setup_test_env
    unset CODESPACES 2>/dev/null || true

    setup_state_persistence &>/dev/null

    assert_dir_exists "$TEST_TEMP_DIR/home/.dotfiles-state" \
        "Setup should create plain directory for ephemeral tier"
    assert_not_symlink "$TEST_TEMP_DIR/home/.dotfiles-state" \
        "Ephemeral should be a real directory, not symlink"

    teardown_test_env
}

test_no_state_persistence_toggle() {
    _setup_toggle_env
    export DOTFILES_NO_STATE_PERSISTENCE=1
    export REMOTE_CONTAINERS=true  # pretend we're in a devcontainer

    local output
    output=$(create_symlinks 2>&1)

    assert_file_not_exists "$TEST_TEMP_DIR/home/.dotfiles-state" \
        "DOTFILES_NO_STATE_PERSISTENCE=1 should not create state dir"
    assert_contains "$output" "DOTFILES_NO_STATE_PERSISTENCE=1" \
        "Should log state persistence skip message"

    unset DOTFILES_NO_STATE_PERSISTENCE REMOTE_CONTAINERS
    teardown_test_env
}

#
# Run all tests
#

main() {
    echo -e "${CYAN}Starting Dotfiles Unit Tests${NC}\n"

    # Symlink function tests
    test_suite "create_symlink Function"
    test_symlink_source_missing
    test_symlink_creates_new_link
    test_symlink_replaces_existing_symlink
    test_symlink_backs_up_real_file
    test_symlink_creates_parent_directories

    # Backup function tests
    test_suite "backup_if_exists Function"
    test_backup_real_file
    test_backup_removes_symlink
    test_backup_nothing_exists
    test_backup_directory

    # Environment detection tests
    test_suite "is_devcontainer Function"
    test_devcontainer_remote_containers
    test_devcontainer_codespaces
    test_devcontainer_neither_set

    # Detect environment tests
    test_suite "detect_environment Function"
    test_detect_codespaces
    test_detect_devcontainer
    test_detect_local

    # Logging module tests
    test_suite "Logging Module"
    test_logging_sources_without_error
    test_logging_double_source_idempotent
    test_logging_output_format

    # Shell config tests
    test_suite "Shell Config"
    test_path_no_duplicates
    test_completion_no_local_at_file_scope

    # State persistence tier tests
    test_suite "State Persistence Tiers"
    test_detect_state_tier_volume
    test_detect_state_tier_symlink_not_volume
    test_detect_state_tier_codespaces
    test_detect_state_tier_ephemeral
    test_setup_state_ephemeral_creates_dir
    test_no_state_persistence_toggle

    # Installation toggle tests
    test_suite "Installation Toggles"
    test_toggle_no_ai_tools_skips_claude_config
    test_toggle_no_ai_tools_skips_codex_config
    test_toggle_no_git_hooks_skips_hooks
    test_toggle_default_installs_all
    test_toggle_no_ai_tools_log_message

    # Print summary
    print_test_summary
}

# Run tests
main
