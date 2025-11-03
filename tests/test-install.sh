#!/usr/bin/env bash
# Test script to validate dotfiles installation

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
FAILED=0
PASSED=0

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
        local version=$(${cmd} --version 2>&1 | head -n 1 || echo "unknown")
        log_pass "$cmd is available ($version)"
    else
        log_fail "$cmd is not available"
    fi
}

# Test if optional command is available (warns instead of fails)
test_command_optional() {
    local cmd=$1
    if command -v "$cmd" &> /dev/null; then
        local version=$(${cmd} --version 2>&1 | head -n 1 || echo "unknown")
        log_pass "$cmd is available ($version)"
    else
        echo -e "${YELLOW}⚠${NC} $cmd is not available (optional)"
    fi
}

# Test if symlink is correct
test_symlink() {
    local link=$1
    local expected=$2
    local name=$3

    if [[ -L "$link" ]]; then
        local actual=$(readlink "$link")
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
test_symlink "$HOME/.gitconfig" "$DOTFILES_DIR/git/.gitconfig" ".gitconfig symlink"
test_symlink "$HOME/.gitignore_global" "$DOTFILES_DIR/git/.gitignore_global" ".gitignore_global symlink"

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
    if timeout 5 bash -i -c 'echo "Bash OK"' &>/dev/null; then
        log_pass "Bash starts successfully"
    else
        log_fail "Bash startup failed or timed out"
    fi
else
    # Fallback for systems without timeout (like some Alpine setups)
    if bash -i -c 'echo "Bash OK"' &>/dev/null; then
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
        if timeout 30 zsh -i -c 'echo "Zsh OK"' &>/dev/null; then
            log_pass "Zsh starts successfully"
        else
            log_fail "Zsh startup failed or timed out"
        fi
    else
        if zsh -i -c 'echo "Zsh OK"' &>/dev/null; then
            log_pass "Zsh starts successfully"
        else
            log_fail "Zsh startup failed"
        fi
    fi
fi

log_section "Environment Variables"
if bash -i -c 'test -n "$EDITOR"' 2>/dev/null; then
    log_pass "EDITOR is set"
else
    log_fail "EDITOR is not set"
fi

if bash -i -c 'test -n "$FZF_DEFAULT_OPTS"' 2>/dev/null; then
    log_pass "FZF_DEFAULT_OPTS is set"
else
    log_fail "FZF_DEFAULT_OPTS is not set"
fi

# Starship init smoke test (non-fatal)
if command -v starship &>/dev/null; then
    if bash -i -c 'eval "$(starship init bash)" >/dev/null 2>&1'; then
        log_pass "Starship init script loads in bash"
    else
        log_fail "Starship init script failed in bash"
    fi
fi

log_section "Git Aliases"
if git config --get alias.s &>/dev/null; then
    log_pass "Git aliases are configured"
else
    log_fail "Git aliases are not configured"
fi

# Summary
log_section "Test Summary"
TOTAL=$((PASSED + FAILED))
echo "Total tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

if [[ $FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed! ✓${NC}\n"
    exit 0
else
    echo -e "\n${YELLOW}Some tests failed. Please review the output above.${NC}\n"
    exit 1
fi
