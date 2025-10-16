#!/usr/bin/env bash
# Dotfiles installation script
# Compatible with VS Code devcontainers, Codespaces, and local installations

# Don't use set -e as we want to handle errors explicitly
set -u  # Error on undefined variables

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}==>${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}!${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_section() { echo -e "\n${MAGENTA}==== $1 ====${NC}\n"; }

# Dotfiles directory
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
export DOTFILES_DIR

# Check if dotfiles directory exists
if [[ ! -d "$DOTFILES_DIR" ]]; then
    log_error "Dotfiles directory not found at $DOTFILES_DIR"
    exit 1
fi

# Change to dotfiles directory
cd "$DOTFILES_DIR" || exit 1

# Source detection script
source "$DOTFILES_DIR/bootstrap/detect.sh"

# Display environment info
log_section "Environment Detection"
ENV_TYPE=$(detect_environment)
OS_TYPE=$(detect_os)
PKG_MGR=$(detect_package_manager)
IS_MINIMAL=$(is_minimal_install && echo "true" || echo "false")

log_info "Environment: $ENV_TYPE"
log_info "Operating System: $OS_TYPE"
log_info "Package Manager: $PKG_MGR"
log_info "Minimal Install: $IS_MINIMAL"

# Make bootstrap scripts executable
chmod +x "$DOTFILES_DIR"/bootstrap/*.sh

# Installation steps
log_section "Installing Packages"
source "$DOTFILES_DIR/bootstrap/packages.sh"
if install_packages; then
    log_success "Packages installed successfully"
else
    log_error "Package installation failed!"
    echo "Please check the error messages above and try running:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y fzf ripgrep fd-find bat"
    exit 1
fi

log_section "Creating Symlinks"
if source "$DOTFILES_DIR/bootstrap/symlinks.sh" && create_symlinks; then
    log_success "Symlinks created successfully"
else
    log_error "Failed to create symlinks"
    exit 1
fi

log_section "Setting up Completions"
if source "$DOTFILES_DIR/bootstrap/completions.sh"; then
    log_success "Completions configured successfully"
else
    log_warn "Some completions may not be available"
fi

# Final message
log_section "Installation Complete"
log_success "Dotfiles installed successfully!"
echo ""
log_info "Next steps:"
echo "  1. Reload your shell: source ~/.bashrc (or ~/.zshrc)"
echo "  2. Set git user info:"
echo "     git config --global user.name \"Your Name\""
echo "     git config --global user.email \"your.email@example.com\""
echo "  3. Customize with local configs:"
echo "     ~/.bashrc.local, ~/.zshrc.local, ~/.gitconfig.local"
echo ""
log_info "Enjoy your new environment! 🚀"
