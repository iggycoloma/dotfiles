#!/usr/bin/env bash
# Dotfiles installation script
# Compatible with VS Code devcontainers, Codespaces, and local installations

# Don't use set -e as we want to handle errors explicitly
set -u  # Error on undefined variables

# Shared logging functions
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bootstrap/logging.sh"

# Dotfiles directory (prefer env var, then script location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$SCRIPT_DIR}"
export DOTFILES_DIR

# In self-edit devcontainers (DOTFILES_WORKSPACE=1), VS Code's dotfiles
# mechanism also runs install.sh from its clone at ~/.dotfiles. Defer that
# invocation -- postCreateCommand runs the canonical install from the workspace.
if [[ -n "${DOTFILES_WORKSPACE:-}" ]] && [[ "$SCRIPT_DIR" != "$DOTFILES_DIR" ]]; then
    log_info "Deferring install to postCreateCommand (DOTFILES_DIR=$DOTFILES_DIR)"
    exit 0
fi

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
    if setup_completions; then
        log_success "Completions configured successfully"
    else
        log_warn "Some completions may not be available"
    fi
else
    log_warn "Completions setup script not found"
fi

log_section "Verifying Git Configuration"
# Git config: dotfiles settings included via [include] in XDG config
# Check if git identity is configured
if git config user.name >/dev/null 2>&1 && git config user.email >/dev/null 2>&1; then
    log_success "Git identity configured: $(git config user.name) <$(git config user.email)>"
else
    log_warn "Git identity not configured"
    log_info "Set with: git config --global user.name \"Your Name\""
    log_info "         git config --global user.email \"your@email.com\""
fi

# SSH commit signing: auto-detect key from agent or local files
# Opt-out via DOTFILES_NO_SSH_SIGNING=1 (accesses ssh-add and ~/.ssh/*.pub)
if [[ "${DOTFILES_NO_SSH_SIGNING:-}" == "1" ]]; then
    log_info "DOTFILES_NO_SSH_SIGNING=1, skipping SSH signing setup"
elif ! git config user.signingkey >/dev/null 2>&1; then
    signing_key=""
    # Try SSH agent first (works with devcontainer forwarding), prefer ed25519
    agent_keys=$(ssh-add -L 2>/dev/null || true)
    if [[ -n "$agent_keys" ]]; then
        signing_key=$(echo "$agent_keys" | grep -m1 'ssh-ed25519' || echo "$agent_keys" | head -1)
    fi

    if [[ -n "$signing_key" ]]; then
        git config --global user.signingkey "key::$signing_key"
        git config --global commit.gpgsign true
        log_success "SSH commit signing configured (from agent)"
    # Fall back to common local key files
    elif [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
        git config --global user.signingkey "$HOME/.ssh/id_ed25519.pub"
        git config --global commit.gpgsign true
        log_success "SSH commit signing configured (ed25519)"
    elif [[ -f "$HOME/.ssh/id_rsa.pub" ]]; then
        git config --global user.signingkey "$HOME/.ssh/id_rsa.pub"
        git config --global commit.gpgsign true
        log_success "SSH commit signing configured (rsa)"
    else
        log_warn "No SSH key found -- commit signing disabled"
        log_info "Add an SSH key and re-run install.sh to enable signing"
    fi

    # Create allowed_signers file if signing key was configured
    if git config user.signingkey >/dev/null 2>&1; then
        local_email=$(git config user.email 2>/dev/null || echo "unknown")
        signers_file="$HOME/.config/git/allowed_signers"
        mkdir -p "$(dirname "$signers_file")"
        # Resolve the key content (handles both key:: prefix and file paths)
        key_value=$(git config user.signingkey)
        if [[ "$key_value" == key::* ]]; then
            key_content="${key_value#key::}"
        elif [[ -f "$key_value" ]]; then
            key_content=$(command cat "$key_value")
        else
            key_content=""
        fi
        if [[ -n "$key_content" ]] && ! grep -qF "$key_content" "$signers_file" 2>/dev/null; then
            echo "$local_email $key_content" > "$signers_file"
            log_success "Created allowed_signers file"
        fi
    fi
else
    log_success "SSH commit signing already configured"
fi

# Final message
log_section "Installation Complete"
log_success "Dotfiles installed successfully!"
echo ""
log_info "Next steps:"
echo "  1. Reload your shell: source ~/.bashrc (or ~/.zshrc)"
echo "  2. Customize with local configs:"
echo "     ~/.bashrc.local, ~/.zshrc.local, ~/.exports.local"
echo ""
log_info "Enjoy your new environment!"
