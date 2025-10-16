#!/usr/bin/env bash
# Symlink management for dotfiles

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}==>${NC} $1"
}

log_success() {
    echo -e "${GREEN}==>${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}==>${NC} $1"
}

log_error() {
    echo -e "${RED}==>${NC} $1"
}

# Backup existing file or directory
backup_if_exists() {
    local target=$1
    if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_warn "Backing up existing $(basename "$target") to $BACKUP_DIR"
        cp -a "$target" "$BACKUP_DIR/"
        rm -rf "$target"
    elif [[ -L "$target" ]]; then
        # Remove existing symlink
        rm "$target"
    fi
}

# Create symlink with backup
create_symlink() {
    local source=$1
    local target=$2

    if [[ ! -e "$source" ]]; then
        log_error "Source does not exist: $source"
        return 1
    fi

    # Create parent directory if needed
    local target_dir
    target_dir=$(dirname "$target")
    mkdir -p "$target_dir"

    # Backup and create symlink
    backup_if_exists "$target"
    ln -sf "$source" "$target"
    log_success "Linked $(basename "$source") -> $target"
}

# Main symlink creation
create_symlinks() {
    log_info "Creating symlinks..."

    # Shell configurations
    create_symlink "$DOTFILES_DIR/shell/.bashrc" "$HOME/.bashrc"
    create_symlink "$DOTFILES_DIR/shell/.bash_profile" "$HOME/.bash_profile"
    create_symlink "$DOTFILES_DIR/shell/.zshrc" "$HOME/.zshrc"
    create_symlink "$DOTFILES_DIR/shell/.zprofile" "$HOME/.zprofile"

    # Git configurations
    create_symlink "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
    create_symlink "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"

    # Vim configuration
    if [[ -f "$DOTFILES_DIR/vim/.vimrc" ]]; then
        create_symlink "$DOTFILES_DIR/vim/.vimrc" "$HOME/.vimrc"
    fi

    # XDG config directory
    mkdir -p "$HOME/.config"

    # Starship configuration
    if [[ -f "$DOTFILES_DIR/config/starship.toml" ]]; then
        create_symlink "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"
    fi

    # Bat configuration
    if [[ -d "$DOTFILES_DIR/config/bat" ]]; then
        create_symlink "$DOTFILES_DIR/config/bat" "$HOME/.config/bat"
    fi

    # Bottom configuration
    if [[ -d "$DOTFILES_DIR/config/bottom" ]]; then
        create_symlink "$DOTFILES_DIR/config/bottom" "$HOME/.config/bottom"
    fi

    # Lazygit configuration
    if [[ -d "$DOTFILES_DIR/config/lazygit" ]]; then
        create_symlink "$DOTFILES_DIR/config/lazygit" "$HOME/.config/lazygit"
    fi

    # Tmux configuration (skip in containers)
    if [[ -f "$DOTFILES_DIR/tmux/.tmux.conf" ]]; then
        source "$DOTFILES_DIR/bootstrap/detect.sh"
        if ! is_minimal_install; then
            create_symlink "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
        fi
    fi

    # Custom bin directory
    if [[ -d "$DOTFILES_DIR/bin" ]]; then
        create_symlink "$DOTFILES_DIR/bin" "$HOME/.local/bin/dotfiles-bin"
    fi

    log_success "Symlinks created successfully!"
    if [[ -d "$BACKUP_DIR" ]]; then
        log_info "Backups saved to: $BACKUP_DIR"
    fi
}

# If run directly (not sourced), execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    create_symlinks
fi
