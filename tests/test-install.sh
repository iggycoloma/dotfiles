#!/usr/bin/env bash
# Test script to validate dotfiles installation

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
FAILED=0
PASSED=0
OPTIONAL_AVAILABLE=0
OPTIONAL_MISSING=0

# Ensure ~/.local/bin is in PATH (where we install tools)
export PATH="$HOME/.local/bin:$PATH"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++)) || true
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++)) || true
}

log_info() {
    echo -e "${BLUE}==>${NC} $1"
}

log_section() {
    echo -e "\n${BLUE}==== $1 ====${NC}\n"
}

# Test if file/directory exists
test_exists() {
    local path=$1
    local name=$2
    if [[ -e "$path" ]]; then
        log_pass "$name exists"
    else
        log_fail "$name does not exist: $path"
    fi
}

# Test if command is available
test_command() {
    local cmd=$1
    if command -v "$cmd" &> /dev/null; then
        local version
        version=$(${cmd} --version 2>&1 | head -n 1 || echo "unknown")
        log_pass "$cmd is available ($version)"
    else
        log_fail "$cmd is not available"
    fi
}

# Test if optional command is available (warns instead of fails)
test_command_optional() {
    local cmd=$1
    if command -v "$cmd" &> /dev/null; then
        local version
        version=$(${cmd} --version 2>&1 | head -n 1 || echo "unknown")
        log_pass "$cmd is available ($version)"
        ((OPTIONAL_AVAILABLE++)) || true
    else
        echo -e "${YELLOW}⚠${NC} $cmd is not available (optional)"
        ((OPTIONAL_MISSING++)) || true
    fi
}

# Test if symlink is correct
test_symlink() {
    local link=$1
    local expected=$2
    local name=$3

    if [[ -L "$link" ]]; then
        local actual
        actual=$(readlink "$link")
        if [[ "$actual" == "$expected" ]]; then
            log_pass "$name is correctly linked"
        else
            log_fail "$name is linked to wrong target: $actual (expected: $expected)"
        fi
    else
        log_fail "$name is not a symlink"
    fi
}

# Main tests
log_section "Repository Structure"
test_exists "$DOTFILES_DIR" "Dotfiles directory"
test_exists "$DOTFILES_DIR/install.sh" "Install script"
test_exists "$DOTFILES_DIR/bootstrap" "Bootstrap directory"
test_exists "$DOTFILES_DIR/shell" "Shell directory"
test_exists "$DOTFILES_DIR/git" "Git directory"
test_exists "$DOTFILES_DIR/config" "Config directory"

log_section "Bootstrap Scripts"
test_exists "$DOTFILES_DIR/bootstrap/detect.sh" "Detection script"
test_exists "$DOTFILES_DIR/bootstrap/packages.sh" "Package script"
test_exists "$DOTFILES_DIR/bootstrap/symlinks.sh" "Symlink script"
test_exists "$DOTFILES_DIR/bootstrap/completions.sh" "Completion script"

log_section "Shell Configuration Files"
test_exists "$DOTFILES_DIR/shell/.bashrc" ".bashrc"
test_exists "$DOTFILES_DIR/shell/.bash_profile" ".bash_profile"
test_exists "$DOTFILES_DIR/shell/.zshrc" ".zshrc"
test_exists "$DOTFILES_DIR/shell/.zprofile" ".zprofile"
test_exists "$DOTFILES_DIR/shell/aliases.sh" "aliases.sh"
test_exists "$DOTFILES_DIR/shell/functions.sh" "functions.sh"
test_exists "$DOTFILES_DIR/shell/exports.sh" "exports.sh"

log_section "Completions Setup"
test_exists "$HOME/.config/zsh/completions.zsh" "Zsh completions config"
test_exists "$HOME/.local/share/bash-completion/completions" "Bash completions directory"

log_section "Git Configuration"
test_exists "$DOTFILES_DIR/git/.gitconfig" ".gitconfig"
test_exists "$DOTFILES_DIR/git/.gitignore_global" ".gitignore_global"

log_section "Symlinks"
test_symlink "$HOME/.bashrc" "$DOTFILES_DIR/shell/.bashrc" ".bashrc symlink"
test_symlink "$HOME/.bash_profile" "$DOTFILES_DIR/shell/.bash_profile" ".bash_profile symlink"
# Note: .gitconfig is NOT symlinked - user identity stays in ~/.gitconfig, settings use XDG location
test_symlink "$HOME/.gitignore_global" "$DOTFILES_DIR/git/.gitignore_global" ".gitignore_global symlink"

log_section "XDG Config Directory Symlinks"
# Test all ~/.config symlinks
# Required configs (must exist)
declare -A required_config_symlinks=(
    ["$HOME/.config/starship.toml"]="$DOTFILES_DIR/config/starship.toml"
    ["$HOME/.config/ripgrep"]="$DOTFILES_DIR/config/ripgrep"
)

# Optional configs (warn if missing)
declare -A optional_config_symlinks=(
    ["$HOME/.config/bat"]="$DOTFILES_DIR/config/bat"
    ["$HOME/.config/bottom"]="$DOTFILES_DIR/config/bottom"
    ["$HOME/.config/lazygit"]="$DOTFILES_DIR/config/lazygit"
)

# Test required config symlinks
for link in "${!required_config_symlinks[@]}"; do
    target="${required_config_symlinks[$link]}"
    name=$(basename "$link")

    # Check if source exists first
    if [[ ! -e "$target" ]]; then
        log_fail "Config source missing: $target"
        continue
    fi

    # Test the symlink
    if [[ -L "$link" ]]; then
        actual=$(readlink "$link")
        if [[ "$actual" == "$target" ]]; then
            # shellcheck disable=SC2088  # tilde is display text, not a path
            log_pass "~/.config/$name symlink correct"
        else
            # shellcheck disable=SC2088
            log_fail "~/.config/$name points to wrong target: $actual"
        fi
    elif [[ -e "$link" ]]; then
        # shellcheck disable=SC2088
        log_fail "~/.config/$name exists but is not a symlink"
    else
        # shellcheck disable=SC2088
        log_fail "~/.config/$name symlink missing"
    fi
done

# Test optional config symlinks (warn only)
for link in "${!optional_config_symlinks[@]}"; do
    target="${optional_config_symlinks[$link]}"
    name=$(basename "$link")

    # Skip if source doesn't exist
    if [[ ! -e "$target" ]]; then
        echo -e "${YELLOW}⚠${NC} Config source not present: $target (optional)"
        continue
    fi

    # Test the symlink
    if [[ -L "$link" ]]; then
        actual=$(readlink "$link")
        if [[ "$actual" == "$target" ]]; then
            # shellcheck disable=SC2088  # tilde is display text
            log_pass "~/.config/$name symlink correct (optional)"
        else
            echo -e "${YELLOW}⚠${NC} ~/.config/$name points to wrong target: $actual (optional)"
        fi
    elif [[ -e "$link" ]]; then
        echo -e "${YELLOW}⚠${NC} ~/.config/$name exists but is not a symlink (optional)"
    else
        echo -e "${YELLOW}⚠${NC} ~/.config/$name symlink missing (optional)"
    fi
done

# Test config loading for tools that are installed
if command -v starship &>/dev/null; then
    # Test that starship can print its config path without opening an editor
    # Note: 'starship config' opens vim, so we test if starship can load the config instead
    if starship print-config &>/dev/null; then
        log_pass "Starship config loads successfully"
    else
        log_fail "Starship config failed to load"
    fi
fi

# Test ripgrep config is readable
if [[ -f "$HOME/.config/ripgrep/config" ]]; then
    if [[ -r "$HOME/.config/ripgrep/config" ]]; then
        log_pass "Ripgrep config is readable"
    else
        log_fail "Ripgrep config is not readable"
    fi
fi

log_section "GitHub Releases Tools"
for tool in eza starship delta atuin zoxide; do
    if command -v "$tool" &>/dev/null; then
        log_pass "$tool is installed"
    else
        log_info "$tool not found (may not be required in this environment)"
    fi
done

log_section "Core Tools"
test_command "git"
test_command "curl"
test_command "bash"

log_section "Modern CLI Tools"
# Core modern tools (installed via package manager)
test_command "fzf"
test_command "rg"
test_command "bat"
test_command "jq"

# Optional tools (installed from GitHub releases, may fail in CI)
log_info "Optional enhanced tools:"
test_command_optional "eza"
test_command_optional "zoxide"
test_command_optional "starship"
test_command_optional "delta"

log_section "Optional Host Tools"
# Check if we're in a container/codespace environment
# Use multiple detection methods for cross-platform compatibility
is_container=false
if [[ -f /.dockerenv ]] || \
   [[ -n "${CODESPACES}" ]] || \
   [[ -n "${REMOTE_CONTAINERS}" ]] || \
   [[ -n "${CI}" ]] || \
   (grep -q "CODESPACES\|REMOTE_CONTAINERS" /proc/1/environ 2>/dev/null); then
    is_container=true
fi

if [[ "$is_container" == "false" ]]; then
    test_command "tmux"
    test_command "lazygit"
else
    log_info "Skipping host-only tools in container environment"
fi

log_section "Shell Startup Test"
log_info "Testing bash startup..."
# Use timeout if available, otherwise use a simple test
if command -v timeout &>/dev/null; then
    # Run in non-interactive mode for faster tests (still sources .bashrc via -l)
    # Interactive mode (-i) can hang if there are issues with job control
    if timeout 5 bash -l -c 'exit 0' &>/dev/null; then
        log_pass "Bash starts successfully"
    else
        log_fail "Bash startup failed or timed out"
    fi
else
    # Fallback for systems without timeout (like some Alpine setups)
    if bash -l -c 'exit 0' &>/dev/null; then
        log_pass "Bash starts successfully"
    else
        log_fail "Bash startup failed"
    fi
fi

if command -v zsh &> /dev/null; then
    log_info "Testing zsh startup..."
    if command -v timeout &>/dev/null; then
        # 30s timeout to handle slower CI runners (especially macOS-13)
        # Also accounts for zinit plugin loading, fzf, zoxide, direnv initialization
        # Use -l instead of -i to avoid job control issues
        if timeout 30 zsh -l -c 'exit 0' &>/dev/null; then
            log_pass "Zsh starts successfully"
        else
            log_fail "Zsh startup failed or timed out"
        fi
    else
        if zsh -l -c 'exit 0' &>/dev/null; then
            log_pass "Zsh starts successfully"
        else
            log_fail "Zsh startup failed"
        fi
    fi
fi

log_section "Environment Variables"
# Use -l -i (login + interactive) to properly source .bashrc (which has interactive check)
if bash -l -i -c 'test -n "$EDITOR"' 2>/dev/null; then
    log_pass "EDITOR is set"
else
    log_fail "EDITOR is not set"
fi

if bash -l -i -c 'test -n "$FZF_DEFAULT_OPTS"' 2>/dev/null; then
    log_pass "FZF_DEFAULT_OPTS is set"
else
    log_fail "FZF_DEFAULT_OPTS is not set"
fi

# Starship init smoke test (optional)
if command -v starship &>/dev/null; then
    if bash -l -c 'eval "$(starship init bash)" >/dev/null 2>&1'; then
        log_pass "Starship init script loads in bash"
    else
        echo -e "${YELLOW}⚠${NC} Starship init script failed in bash (optional)"
    fi
else
    log_info "Starship not installed (skipping init test)"
fi

log_section "Git Aliases"
if git config --get alias.s &>/dev/null; then
    log_pass "Git aliases are configured"
else
    log_fail "Git aliases are not configured"
fi

log_section "Git XDG Configuration"
# Test XDG git config includes dotfiles settings via [include]
if [[ -f "$HOME/.config/git/config" ]] && ! [[ -L "$HOME/.config/git/config" ]] && grep -qF "$DOTFILES_DIR/git/.gitconfig" "$HOME/.config/git/config"; then
    log_pass "Git XDG config includes dotfiles settings via [include]"
else
    log_fail "Git XDG config should be a real file with [include] for dotfiles settings"
fi

# Test global git hooks symlink
test_symlink "$HOME/.config/git/hooks" "$DOTFILES_DIR/git/hooks" "Git global hooks"

# Test dotfiles settings loaded via XDG config
if git config --get core.pager | grep -q "delta"; then
    log_pass "Dotfiles git core.pager configured (loaded from XDG)"
else
    log_fail "Dotfiles git settings not loaded from XDG config"
fi

# Verify git config hierarchy: user identity in ~/.gitconfig, dotfiles in XDG via [include]
if [[ -f "$HOME/.gitconfig" ]]; then
    if git config --file "$HOME/.gitconfig" user.email &>/dev/null; then
        log_pass "User identity in ~/.gitconfig (separate from dotfiles settings)"
    fi
fi

# Verify git identity (critical for all environments)
if git config user.name >/dev/null 2>&1 && git config user.email >/dev/null 2>&1; then
    log_pass "Git identity configured: $(git config user.name) <$(git config user.email)>"
else
    # This is a FAIL in CI environments (containers, Codespaces)
    if [[ -n "${CI:-}" ]] || [[ -n "${CODESPACES:-}" ]]; then
        log_fail "Git identity MUST be configured in CI/Codespaces"
    else
        log_info "Git identity not configured (expected on fresh local install)"
    fi
fi

# Codespaces-specific checks
if [[ -n "${CODESPACES:-}" ]]; then
    log_info "Detected Codespaces environment"
    if git config --system user.name >/dev/null 2>&1; then
        log_pass "Codespaces system-level git identity present"
    else
        log_warn "Codespaces should have system-level git identity"
    fi
fi

# Summary
log_section "Test Summary"
TOTAL=$((PASSED + FAILED))
echo "Required tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

# Optional tools summary
if [[ $((OPTIONAL_AVAILABLE + OPTIONAL_MISSING)) -gt 0 ]]; then
    echo ""
    echo "Optional tools: $((OPTIONAL_AVAILABLE + OPTIONAL_MISSING))"
    echo -e "${GREEN}Available: $OPTIONAL_AVAILABLE${NC}"
    echo -e "${YELLOW}Missing: $OPTIONAL_MISSING${NC}"
fi

if [[ $FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All required tests passed! ✓${NC}\n"
    exit 0
else
    echo -e "\n${YELLOW}Some tests failed. Please review the output above.${NC}\n"
    exit 1
fi
