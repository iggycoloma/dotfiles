#!/usr/bin/env bash
# Symlink management for dotfiles

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
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

# Ensure a directory symlink points to the volume, migrating any existing
# contents. If target is a real directory, its contents are merged into the
# volume first. Idempotent.
setup_volume_dir() {
    local vol_path="$1"
    local target_path="$2"
    mkdir -p "$vol_path"
    if [[ -d "$target_path" ]] && [[ ! -L "$target_path" ]]; then
        # Merge existing contents into volume, then replace with symlink
        if ! cp -a "$target_path"/. "$vol_path"/ 2>&1; then
            log_warn "Failed to migrate $target_path to volume; leaving in place"
            return 1
        fi
        rm -rf "$target_path"
    elif [[ -L "$target_path" ]]; then
        rm -f "$target_path"
    fi
    ln -snf "$vol_path" "$target_path"
}

# Force-copy config files and directories from dotfiles into a target dir.
# Directories are removed first to avoid stale files from previous versions.
stomp_configs() {
    local source_dir="$1"
    local target_dir="$2"
    shift 2
    # Remaining args: files and directories to copy
    for item in "$@"; do
        local src="$source_dir/$item"
        local dst="$target_dir/$item"
        [[ -e "$src" ]] || continue
        if [[ -d "$src" ]]; then
            rm -rf "$dst"
            cp -rf "$src" "$dst"
        else
            # Remove symlink if present (migration from old setup)
            [[ -L "$dst" ]] && rm -f "$dst"
            cp -f "$src" "$dst"
        fi
    done
}

# Main symlink creation
create_symlinks() {
    log_info "Creating symlinks..."

    source "$DOTFILES_DIR/bootstrap/detect.sh"

    # Fix volume ownership in devcontainers (may be root-owned on first mount)
    if [[ -d "$HOME/.devcontainer-state" ]]; then
        if [[ ! -w "$HOME/.devcontainer-state" ]] && command -v sudo >/dev/null 2>&1; then
            sudo chown -R "$(id -u):$(id -g)" "$HOME/.devcontainer-state"
        fi
    fi

    # Shell configurations
    create_symlink "$DOTFILES_DIR/shell/.bashrc" "$HOME/.bashrc"
    create_symlink "$DOTFILES_DIR/shell/.bash_profile" "$HOME/.bash_profile"
    create_symlink "$DOTFILES_DIR/shell/.zshrc" "$HOME/.zshrc"
    create_symlink "$DOTFILES_DIR/shell/.zprofile" "$HOME/.zprofile"

    # Git configurations
    # Symlink .gitconfig to XDG location (works everywhere including devcontainers)
    # User's personal ~/.gitconfig (identity) + XDG config (dotfiles settings) = merged by Git
    create_symlink "$DOTFILES_DIR/git/.gitconfig" "$HOME/.config/git/config"
    create_symlink "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"
    create_symlink "$DOTFILES_DIR/git/.gitmessage" "$HOME/.gitmessage"
    # Global Git hooks (applies to all repos via core.hooksPath)
    if [[ -d "$DOTFILES_DIR/git/hooks" ]]; then
        # Ensure hooks are executable
        for file in "$DOTFILES_DIR/git/hooks"/*; do
            [ -f "$file" ] || continue
            chmod +x "$file" || true
        done
        create_symlink "$DOTFILES_DIR/git/hooks" "$HOME/.config/git/hooks"
    fi

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

    # Ripgrep configuration
    if [[ -d "$DOTFILES_DIR/config/ripgrep" ]]; then
        create_symlink "$DOTFILES_DIR/config/ripgrep" "$HOME/.config/ripgrep"
    fi

    # Claude Code configuration
    if [[ -d "$DOTFILES_DIR/claude-code" ]]; then
        log_info "Setting up Claude Code configuration..."

        if is_devcontainer; then
            # Devcontainer: config + state live together in ~/.claude.
            # If the state volume is mounted, ~/.claude is a directory symlink
            # into the volume so that atomic writes (temp + rename) land on the
            # volume filesystem instead of breaking a file-level symlink.
            if [[ -d "$HOME/.devcontainer-state" ]]; then
                setup_volume_dir "$HOME/.devcontainer-state/claude" "$HOME/.claude"
                log_success "$HOME/.claude -> volume"
            else
                mkdir -p "$HOME/.claude"
            fi

            # Force-copy configs from dotfiles (refreshed every boot)
            stomp_configs "$DOTFILES_DIR/claude-code" "$HOME/.claude" \
                settings.json CLAUDE.md statusline.sh hooks agents commands
            # Make scripts executable
            [[ -f "$HOME/.claude/statusline.sh" ]] && chmod +x "$HOME/.claude/statusline.sh"
            for f in "$HOME/.claude/hooks"/*.sh; do
                [[ -f "$f" ]] && chmod +x "$f"
            done

        else
            # Local: symlink configs to dotfiles repo
            for f in settings.json CLAUDE.md statusline.sh; do
                if [[ -f "$DOTFILES_DIR/claude-code/$f" ]]; then
                    [[ "$f" == "statusline.sh" ]] && chmod +x "$DOTFILES_DIR/claude-code/$f"
                    create_symlink "$DOTFILES_DIR/claude-code/$f" "$HOME/.claude/$f"
                fi
            done
            for d in hooks agents commands; do
                if [[ -d "$DOTFILES_DIR/claude-code/$d" ]]; then
                    if [[ "$d" == "hooks" ]]; then
                        for file in "$DOTFILES_DIR/claude-code/hooks"/*.sh; do
                            [ -f "$file" ] || continue
                            chmod +x "$file"
                        done
                    fi
                    create_symlink "$DOTFILES_DIR/claude-code/$d" "$HOME/.claude/$d"
                fi
            done
        fi

        log_success "Claude Code configuration complete"
    else
        log_info "Claude Code directory not found, skipping Claude Code setup"
    fi

    # Codex configuration
    if [[ -d "$DOTFILES_DIR/codex" ]]; then
        log_info "Setting up .codex configuration..."

        if is_devcontainer; then
            # Devcontainer: directory symlink into volume (or plain dir)
            if [[ -d "$HOME/.devcontainer-state" ]]; then
                setup_volume_dir "$HOME/.devcontainer-state/codex" "$HOME/.codex"
                log_success "$HOME/.codex -> volume"
            else
                mkdir -p "$HOME/.codex"
            fi

            # Force-copy configs from dotfiles (refreshed every boot)
            stomp_configs "$DOTFILES_DIR/codex" "$HOME/.codex" \
                AGENTS.md hooks
            # Managed skill directories: copy individually to preserve .system
            if [[ -d "$DOTFILES_DIR/codex/skills" ]]; then
                mkdir -p "$HOME/.codex/skills"
                for skill_dir in "$DOTFILES_DIR/codex/skills"/*; do
                    [[ -d "$skill_dir" ]] || continue
                    local skill_name
                    skill_name=$(basename "$skill_dir")
                    rm -rf "$HOME/.codex/skills/$skill_name"
                    cp -rf "$skill_dir" "$HOME/.codex/skills/$skill_name"
                done
            fi
            # config.toml: preserve if it exists (local trust + preferences)
            if [[ -f "$DOTFILES_DIR/codex/config.toml" ]] && [[ ! -e "$HOME/.codex/config.toml" ]]; then
                cp -f "$DOTFILES_DIR/codex/config.toml" "$HOME/.codex/config.toml"
            fi
            # Make hooks executable
            for f in "$HOME/.codex/hooks"/*.sh; do
                [[ -f "$f" ]] && chmod +x "$f"
            done
        else
            # Local: symlink configs to dotfiles repo
            # Migrate from old whole-directory symlink
            if [[ -L "$HOME/.codex" ]]; then
                log_warn "Removing old whole-directory symlink ~/.codex (migrating to managed files)"
                rm "$HOME/.codex"
            fi
            mkdir -p "$HOME/.codex"

            if [[ -f "$DOTFILES_DIR/codex/AGENTS.md" ]]; then
                create_symlink "$DOTFILES_DIR/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
            fi
            if [[ -f "$DOTFILES_DIR/codex/config.toml" ]]; then
                if [[ -e "$HOME/.codex/config.toml" ]] && [[ ! -L "$HOME/.codex/config.toml" ]]; then
                    log_warn "Skipping ~/.codex/config.toml (preserving local Codex settings)"
                else
                    create_symlink "$DOTFILES_DIR/codex/config.toml" "$HOME/.codex/config.toml"
                fi
            fi
            if [[ -d "$DOTFILES_DIR/codex/skills" ]]; then
                mkdir -p "$HOME/.codex/skills"
                for skill_dir in "$DOTFILES_DIR/codex/skills"/*; do
                    [[ -d "$skill_dir" ]] || continue
                    create_symlink "$skill_dir" "$HOME/.codex/skills/$(basename "$skill_dir")"
                done
            fi
            if [[ -d "$DOTFILES_DIR/codex/hooks" ]]; then
                mkdir -p "$HOME/.codex/hooks"
                for file in "$DOTFILES_DIR/codex/hooks"/*.sh; do
                    [ -f "$file" ] || continue
                    chmod +x "$file"
                    create_symlink "$file" "$HOME/.codex/hooks/$(basename "$file")"
                done
            fi
        fi

        # Ensure notify hook is wired in config.toml (non-destructive)
        if [[ -f "$HOME/.codex/hooks/notify.sh" ]]; then
            if [[ -f "$HOME/.codex/config.toml" ]]; then
                if ! grep -q '^notify\s*=' "$HOME/.codex/config.toml"; then
                    log_info "Adding notify hook to ~/.codex/config.toml"
                    printf '\nnotify = "bash %s/.codex/hooks/notify.sh"\n' "$HOME" >> "$HOME/.codex/config.toml"
                fi
            else
                log_info "Creating ~/.codex/config.toml with notify hook"
                printf 'notify = "bash %s/.codex/hooks/notify.sh"\n' "$HOME" > "$HOME/.codex/config.toml"
            fi
        fi

        log_success ".codex configuration complete"
    fi

    # Tmux configuration (skip in containers)
    if [[ -f "$DOTFILES_DIR/tmux/.tmux.conf" ]]; then
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
