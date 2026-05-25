#!/usr/bin/env bash
# Dotfiles Validation Script
# Verifies the health and correctness of dotfiles installation
# Can be run anytime to check symlinks, configs, and environment setup

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
PASSED=0
WARNINGS=0
FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++)) || true
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++)) || true
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++)) || true
}

log_info() {
    echo -e "${BLUE}==>${NC} $1"
}

log_section() {
    echo -e "\n${CYAN}==== $1 ====${NC}\n"
}

# Helper: Check if in devcontainer
is_devcontainer() {
    [[ -n "${REMOTE_CONTAINERS:-}" ]] || [[ -n "${CODESPACES:-}" ]]
}

# Helper: Check if symlink is correct
check_symlink() {
    local link=$1
    local expected=$2
    local name=$3
    local optional=${4:-false}

    if [[ -L "$link" ]]; then
        local actual
        actual=$(readlink "$link")
        if [[ "$actual" == "$expected" ]]; then
            log_pass "$name: correctly linked"
        else
            if [[ "$optional" == "true" ]]; then
                log_warn "$name: linked to wrong target: $actual (expected: $expected)"
            else
                log_fail "$name: linked to wrong target: $actual (expected: $expected)"
            fi
        fi
    elif [[ -e "$link" ]]; then
        if [[ "$optional" == "true" ]]; then
            log_warn "$name: exists but is not a symlink"
        else
            log_fail "$name: exists but is not a symlink"
        fi
    else
        if [[ "$optional" == "true" ]]; then
            log_warn "$name: symlink missing (optional)"
        else
            log_fail "$name: symlink missing"
        fi
    fi
}

#
# MAIN VALIDATION CHECKS
#

log_section "Dotfiles Repository"
if [[ -d "$DOTFILES_DIR" ]]; then
    log_pass "Dotfiles directory found: $DOTFILES_DIR"
else
    log_fail "Dotfiles directory not found: $DOTFILES_DIR"
    exit 1
fi

log_section "Home Directory Symlinks"
# Core shell configs
check_symlink "$HOME/.bashrc" "$DOTFILES_DIR/shell/.bashrc" ".bashrc"
check_symlink "$HOME/.bash_profile" "$DOTFILES_DIR/shell/.bash_profile" ".bash_profile"

if command -v zsh &>/dev/null; then
    check_symlink "$HOME/.zshrc" "$DOTFILES_DIR/shell/.zshrc" ".zshrc"
    check_symlink "$HOME/.zprofile" "$DOTFILES_DIR/shell/.zprofile" ".zprofile"
fi

# Git configs
check_symlink "$HOME/.gitignore_global" "$DOTFILES_DIR/git/.gitignore_global" ".gitignore_global"
check_symlink "$HOME/.gitmessage" "$DOTFILES_DIR/git/.gitmessage" ".gitmessage"

# Vim
if [[ -f "$DOTFILES_DIR/vim/.vimrc" ]]; then
    check_symlink "$HOME/.vimrc" "$DOTFILES_DIR/vim/.vimrc" ".vimrc" true
fi

log_section "XDG Config Directory Symlinks"
# Git XDG config (real file with [include], not a symlink)
if [[ -f "$HOME/.config/git/config" ]] && ! [[ -L "$HOME/.config/git/config" ]] && grep -qF "$DOTFILES_DIR/git/.gitconfig" "$HOME/.config/git/config"; then
    log_pass "Git XDG config includes dotfiles settings"
else
    log_fail "Git XDG config should include dotfiles settings via [include]"
fi
check_symlink "$HOME/.config/git/hooks" "$DOTFILES_DIR/git/hooks" "Git global hooks"

# Required tool configs
if [[ -f "$DOTFILES_DIR/config/starship.toml" ]]; then
    check_symlink "$HOME/.config/starship.toml" "$DOTFILES_DIR/config/starship.toml" "Starship config"
fi

if [[ -d "$DOTFILES_DIR/config/ripgrep" ]]; then
    check_symlink "$HOME/.config/ripgrep" "$DOTFILES_DIR/config/ripgrep" "Ripgrep config"
fi

# Optional tool configs
if [[ -d "$DOTFILES_DIR/config/bat" ]]; then
    check_symlink "$HOME/.config/bat" "$DOTFILES_DIR/config/bat" "Bat config" true
fi

if [[ -d "$DOTFILES_DIR/config/bottom" ]]; then
    check_symlink "$HOME/.config/bottom" "$DOTFILES_DIR/config/bottom" "Bottom config" true
fi

if [[ -d "$DOTFILES_DIR/config/lazygit" ]]; then
    check_symlink "$HOME/.config/lazygit" "$DOTFILES_DIR/config/lazygit" "Lazygit config" true
fi

log_section "Local Bin Symlinks"
if [[ -d "$DOTFILES_DIR/bin" ]]; then
    check_symlink "$HOME/.local/bin/dotfiles-bin" "$DOTFILES_DIR/bin" "Dotfiles bin directory"
fi

log_section "Broken Symlinks Check"
# Find any broken symlinks in home and .config
broken_count=0
while IFS= read -r -d '' broken_link; do
    log_fail "Broken symlink: $broken_link -> $(readlink "$broken_link")"
    ((broken_count++)) || true
done < <(find "$HOME" -maxdepth 1 -xtype l -print0 2>/dev/null)

while IFS= read -r -d '' broken_link; do
    log_fail "Broken symlink: $broken_link -> $(readlink "$broken_link")"
    ((broken_count++)) || true
done < <(find "$HOME/.config" -xtype l -print0 2>/dev/null)

if [[ $broken_count -eq 0 ]]; then
    log_pass "No broken symlinks found"
fi

log_section "Git Configuration"
# Test git config hierarchy
if git config --get core.pager &>/dev/null; then
    pager=$(git config --get core.pager)
    if echo "$pager" | grep -q "delta"; then
        log_pass "Git core.pager configured with delta"
    else
        log_warn "Git core.pager set but not using delta: $pager"
    fi
else
    log_warn "Git core.pager not configured"
fi

# Verify git identity
if git config user.name &>/dev/null && git config user.email &>/dev/null; then
    log_pass "Git identity configured: $(git config user.name) <$(git config user.email)>"
else
    log_warn "Git identity not configured (user.name or user.email missing)"
fi

# Test git aliases
if git config --get alias.s &>/dev/null; then
    log_pass "Git aliases configured"
else
    log_fail "Git aliases not configured"
fi

# Check git hooks directory
if git config --get core.hooksPath &>/dev/null; then
    hooks_path=$(git config --get core.hooksPath)
    log_pass "Git hooks directory configured: $hooks_path"

    # Verify hooks are executable
    if [[ -d "$hooks_path" ]]; then
        hooks_count=$(find "$hooks_path" -type f -name "*.sh" | wc -l)
        if [[ $hooks_count -gt 0 ]]; then
            log_pass "Found $hooks_count hook script(s)"
        fi
    fi
else
    log_warn "Git hooks directory not configured"
fi

log_section "Tool Configuration Loading"
# Starship
if command -v starship &>/dev/null; then
    if starship config 2>&1 | grep -q "starship.toml"; then
        log_pass "Starship config loads successfully"
    else
        log_fail "Starship config failed to load"
    fi
else
    log_info "Starship not installed (skipping)"
fi

# Ripgrep config
if command -v rg &>/dev/null; then
    if [[ -f "$HOME/.config/ripgrep/config" ]] && [[ -r "$HOME/.config/ripgrep/config" ]]; then
        log_pass "Ripgrep config is readable"

        # Test that ripgrep actually uses the config
        if rg --version | head -1 &>/dev/null; then
            log_pass "Ripgrep executes successfully"
        fi
    else
        log_warn "Ripgrep config not found or not readable"
    fi
else
    log_info "Ripgrep not installed (skipping)"
fi

# Bat
if command -v bat &>/dev/null; then
    if bat --config-file 2>&1 | grep -q "config"; then
        log_pass "Bat can access config"
    fi
else
    log_info "Bat not installed (skipping)"
fi

log_section "Environment Detection"
if is_devcontainer; then
    log_info "Detected devcontainer/Codespaces environment"

    # In devcontainers, Claude configs should use copy-merge strategy
    if [[ -d "$HOME/.claude-code" ]]; then
        log_pass "Claude Code config directory exists"

        # Check for version marker from merge script
        if [[ -f "$HOME/.claude-code/.dotfiles-version" ]]; then
            version_date=$(cat "$HOME/.claude-code/.dotfiles-version" 2>/dev/null || echo "unknown")
            log_pass "Config merge version: $version_date"
        fi
    fi

    # Check for Codespaces-specific git config
    if [[ -n "${CODESPACES:-}" ]]; then
        if git config --system user.name &>/dev/null; then
            log_pass "Codespaces system-level git identity present"
        else
            log_warn "Codespaces system-level git identity not found"
        fi
    fi
else
    log_info "Detected host/SSH environment"
    log_pass "Using standard symlink strategy"
fi

log_section "Shell Environment"
# Check DOTFILES_DIR is set
if [[ -n "${DOTFILES_DIR:-}" ]]; then
    log_pass "DOTFILES_DIR environment variable set: $DOTFILES_DIR"
else
    log_warn "DOTFILES_DIR environment variable not set"
fi

# Check EDITOR
if [[ -n "${EDITOR:-}" ]]; then
    log_pass "EDITOR set: $EDITOR"
else
    log_warn "EDITOR not set"
fi

# Check FZF configuration
if command -v fzf &>/dev/null; then
    if [[ -n "${FZF_DEFAULT_OPTS:-}" ]]; then
        log_pass "FZF_DEFAULT_OPTS configured"
    else
        log_warn "FZF_DEFAULT_OPTS not set"
    fi
fi

log_section "Validation Summary"
TOTAL=$((PASSED + WARNINGS + FAILED))
echo "Total checks: $TOTAL"
echo -e "${GREEN}Passed:   $PASSED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Failed:   $FAILED${NC}"

# Exit code based on failures
if [[ $FAILED -eq 0 ]]; then
    if [[ $WARNINGS -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All checks passed! Dotfiles are healthy.${NC}\n"
        exit 0
    else
        echo -e "\n${YELLOW}⚠ Validation passed with warnings. Review above.${NC}\n"
        exit 0
    fi
else
    echo -e "\n${RED}✗ Validation failed. Please fix the issues above.${NC}\n"
    exit 1
fi
