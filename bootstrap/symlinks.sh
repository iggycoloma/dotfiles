#!/usr/bin/env bash
# Symlink management for dotfiles

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# Shared logging and detection functions
source "$DOTFILES_DIR/bootstrap/logging.sh"
source "$DOTFILES_DIR/bootstrap/detect.sh"

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

# Ensure the user's git config includes the dotfiles git settings.
# Uses [include] so ~/.config/git/config stays writable for personal settings
# (signing keys) without dirtying the repo. Converts old symlink on migration.
_ensure_git_include() {
    local dotfiles_gitconfig="$1"
    local xdg_config="$HOME/.config/git/config"
    mkdir -p "$(dirname "$xdg_config")"

    # Migrate from old symlink to real file
    if [[ -L "$xdg_config" ]]; then
        log_info "Migrating git config from symlink to [include] pattern"
        rm -f "$xdg_config"
    fi

    # Check if include already present
    if [[ -f "$xdg_config" ]] && grep -qF "$dotfiles_gitconfig" "$xdg_config" 2>/dev/null; then
        log_success "Git config already includes dotfiles settings"
        return 0
    fi

    # Prepend include (dotfiles = defaults, user settings override)
    local tmp
    tmp=$(mktemp)
    printf '[include]\n\tpath = %s\n' "$dotfiles_gitconfig" > "$tmp"
    if [[ -f "$xdg_config" ]]; then
        cat "$xdg_config" >> "$tmp"
    fi
    mv "$tmp" "$xdg_config"
    log_success "Added [include] for dotfiles git settings"
}

# Wire up state persistence based on detect_state_tier() result.
# Creates directories, symlinks, and sets permissions.
setup_state_persistence() {
    detect_state_tier

    case "$STATE_TIER" in
        volume)
            log_info "State persistence: volume (existing mount)"
            ;;
        codespaces)
            if mkdir -p "$STATE_PATH" 2>/dev/null; then
                ln -snf "$STATE_PATH" "$HOME/.dotfiles-state"
                chmod 700 "$STATE_PATH"
                log_info "State persistence: codespaces ($STATE_PATH)"
            else
                log_warn "Codespaces persistedshare not writable, falling back to ephemeral"
                mkdir -p "$HOME/.dotfiles-state"
                chmod 700 "$HOME/.dotfiles-state"
                STATE_TIER="ephemeral"
            fi
            ;;
        ephemeral)
            mkdir -p "$HOME/.dotfiles-state"
            chmod 700 "$HOME/.dotfiles-state"
            log_warn "State persistence: ephemeral (state lost on rebuild)"
            log_info "Add this to your devcontainer.json for persistent state:"
            # shellcheck disable=SC2016  # literal JSON example, not meant to expand
            log_info '  "mounts": ["source=${devcontainerId}-state,target=/home/vscode/.dotfiles-state,type=volume"]'
            ;;
    esac
}

# Wire up the target directory for a tool's config in devcontainers.
# If state persistence is available, uses a volume-backed directory symlink.
# Otherwise creates a plain directory.
_wire_tool_dir() {
    local state_subdir="$1" target_dir="$2"
    if is_devcontainer && [[ -d "$HOME/.dotfiles-state" ]]; then
        setup_volume_dir "$HOME/.dotfiles-state/$state_subdir" "$target_dir"
        log_success "$target_dir -> state"
    elif is_devcontainer; then
        mkdir -p "$target_dir"
    fi
}

# Make all .sh files in a directory executable.
_chmod_hooks() {
    local dir="$1"
    for f in "$dir"/*.sh; do
        [[ -f "$f" ]] && chmod +x "$f"
    done
}

# Deploy config files and directories from dotfiles source to target.
# In devcontainers: force-copies (stomp) so configs refresh every boot.
# On host: creates symlinks to dotfiles repo for live editing.
# Args: source_dir target_dir files... -- directories...
#   files and directories are separated by "--"
_deploy_configs() {
    local source_dir="$1" target_dir="$2"
    shift 2

    # Split args into files and directories at "--"
    local files=() dirs=()
    local in_dirs=false
    for arg in "$@"; do
        if [[ "$arg" == "--" ]]; then
            in_dirs=true
            continue
        fi
        if $in_dirs; then
            dirs+=("$arg")
        else
            files+=("$arg")
        fi
    done

    if is_devcontainer; then
        stomp_configs "$source_dir" "$target_dir" "${files[@]}" ${dirs[@]+"${dirs[@]}"}
        [[ -d "$target_dir/hooks" ]] && _chmod_hooks "$target_dir/hooks"
    else
        mkdir -p "$target_dir"
        for f in "${files[@]}"; do
            if [[ -f "$source_dir/$f" ]]; then
                [[ "$f" == *.sh ]] && chmod +x "$source_dir/$f"
                create_symlink "$source_dir/$f" "$target_dir/$f"
            fi
        done
        for d in ${dirs[@]+"${dirs[@]}"}; do
            if [[ -d "$source_dir/$d" ]]; then
                [[ "$d" == "hooks" ]] && _chmod_hooks "$source_dir/$d"
                create_symlink "$source_dir/$d" "$target_dir/$d"
            fi
        done
    fi
}

_setup_claude_code() {
    log_info "Setting up Claude Code configuration..."

    _wire_tool_dir "claude" "$HOME/.claude"

    # Migrate legacy ~/.claude.json -> ~/.claude/config.json
    if [[ -f "$HOME/.claude.json" ]] && [[ ! -L "$HOME/.claude.json" ]] && [[ ! -f "$HOME/.claude/config.json" ]]; then
        mv "$HOME/.claude.json" "$HOME/.claude/config.json"
        log_success "Migrated ~/.claude.json -> ~/.claude/config.json"
    fi

    _deploy_configs "$DOTFILES_DIR/claude-code" "$HOME/.claude" \
        settings.json CLAUDE.md statusline.sh -- hooks agents commands

    log_success "Claude Code configuration complete"
}

_setup_codex() {
    log_info "Setting up Codex configuration..."

    # Migrate from old whole-directory symlink (local only)
    if ! is_devcontainer && [[ -L "$HOME/.codex" ]]; then
        log_warn "Removing old whole-directory symlink ~/.codex (migrating to managed files)"
        rm "$HOME/.codex"
    fi

    _wire_tool_dir "codex" "$HOME/.codex"

    _deploy_configs "$DOTFILES_DIR/codex" "$HOME/.codex" \
        AGENTS.md -- hooks

    # Skills: copy subdirectories individually (preserves .system in devcontainer)
    if [[ -d "$DOTFILES_DIR/codex/skills" ]]; then
        if is_devcontainer; then
            mkdir -p "$HOME/.codex/skills"
            for skill_dir in "$DOTFILES_DIR/codex/skills"/*; do
                [[ -d "$skill_dir" ]] || continue
                local skill_name
                skill_name=$(basename "$skill_dir")
                rm -rf "$HOME/.codex/skills/$skill_name"
                cp -rf "$skill_dir" "$HOME/.codex/skills/$skill_name"
            done
        else
            mkdir -p "$HOME/.codex/skills"
            for skill_dir in "$DOTFILES_DIR/codex/skills"/*; do
                [[ -d "$skill_dir" ]] || continue
                create_symlink "$skill_dir" "$HOME/.codex/skills/$(basename "$skill_dir")"
            done
        fi
    fi

    # config.toml: preserve existing (local trust + preferences)
    if [[ -f "$DOTFILES_DIR/codex/config.toml" ]]; then
        if is_devcontainer; then
            [[ ! -e "$HOME/.codex/config.toml" ]] && cp -f "$DOTFILES_DIR/codex/config.toml" "$HOME/.codex/config.toml"
        else
            if [[ -e "$HOME/.codex/config.toml" ]] && [[ ! -L "$HOME/.codex/config.toml" ]]; then
                log_warn "Skipping ~/.codex/config.toml (preserving local Codex settings)"
            else
                create_symlink "$DOTFILES_DIR/codex/config.toml" "$HOME/.codex/config.toml"
            fi
        fi
    fi

    # Ensure notify hook is wired in config.toml
    _setup_codex_notify

    log_success "Codex configuration complete"
}

_setup_copilot() {
    log_info "Setting up Copilot CLI configuration..."

    _wire_tool_dir "copilot" "$HOME/.copilot"

    _deploy_configs "$DOTFILES_DIR/copilot" "$HOME/.copilot" \
        copilot-instructions.md

    log_success "Copilot CLI configuration complete"
}

_setup_codex_notify() {
    [[ -f "$HOME/.codex/hooks/notify.sh" ]] || return 0

    if [[ -f "$HOME/.codex/config.toml" ]]; then
        # Fix legacy string format -> array format
        if grep -q '^notify\s*=\s*"' "$HOME/.codex/config.toml"; then
            log_info "Fixing notify hook format in ~/.codex/config.toml (string -> array)"
            if command -v sd >/dev/null 2>&1; then
                # shellcheck disable=SC2016  # $1 is a regex capture group, not a shell variable
                sd '^notify\s*=\s*"bash (.+)"' 'notify = ["bash", "$1"]' "$HOME/.codex/config.toml"
            else
                sed -i 's|^notify\s*=\s*"bash \(.*\)"|notify = ["bash", "\1"]|' "$HOME/.codex/config.toml"
            fi
        elif ! grep -q '^notify\s*=' "$HOME/.codex/config.toml"; then
            log_info "Adding notify hook to ~/.codex/config.toml"
            printf '\nnotify = ["bash", "%s/.codex/hooks/notify.sh"]\n' "$HOME" >> "$HOME/.codex/config.toml"
        fi
    else
        log_info "Creating ~/.codex/config.toml with notify hook"
        printf 'notify = ["bash", "%s/.codex/hooks/notify.sh"]\n' "$HOME" > "$HOME/.codex/config.toml"
    fi
}

# Main symlink creation
create_symlinks() {
    log_info "Creating symlinks..."

    # Set up state persistence tier (devcontainers only)
    # Opt-out via DOTFILES_NO_STATE_PERSISTENCE=1
    if is_devcontainer && [[ "${DOTFILES_NO_STATE_PERSISTENCE:-}" != "1" ]]; then
        setup_state_persistence
    elif [[ "${DOTFILES_NO_STATE_PERSISTENCE:-}" == "1" ]]; then
        log_info "DOTFILES_NO_STATE_PERSISTENCE=1, skipping state persistence setup"
    fi

    # Fix ownership and permissions (may be root-owned on first mount)
    if [[ -d "$HOME/.dotfiles-state" ]]; then
        if [[ ! -w "$HOME/.dotfiles-state" ]] && command -v sudo >/dev/null 2>&1; then
            sudo chown -R "$(id -u):$(id -g)" "$HOME/.dotfiles-state"
        fi
        chmod 700 "$HOME/.dotfiles-state"
    fi

    # Shell configurations
    create_symlink "$DOTFILES_DIR/shell/.bashrc" "$HOME/.bashrc"
    create_symlink "$DOTFILES_DIR/shell/.bash_profile" "$HOME/.bash_profile"
    create_symlink "$DOTFILES_DIR/shell/.zshrc" "$HOME/.zshrc"
    create_symlink "$DOTFILES_DIR/shell/.zprofile" "$HOME/.zprofile"

    # Git configurations
    # Include dotfiles git settings via [include] in the XDG config.
    # VS Code copies host ~/.gitconfig (identity) into devcontainers.
    # The XDG config is a real file so git config --global writes are safe.
    _ensure_git_include "$DOTFILES_DIR/git/.gitconfig"
    create_symlink "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"
    create_symlink "$DOTFILES_DIR/git/.gitmessage" "$HOME/.gitmessage"
    # Global Git hooks (applies to all repos via core.hooksPath)
    # Opt-out via DOTFILES_NO_GIT_HOOKS=1
    if [[ "${DOTFILES_NO_GIT_HOOKS:-}" != "1" ]] && [[ -d "$DOTFILES_DIR/git/hooks" ]]; then
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

    # Yazi configuration
    if [[ -d "$DOTFILES_DIR/config/yazi" ]]; then
        create_symlink "$DOTFILES_DIR/config/yazi" "$HOME/.config/yazi"
    fi

    # Ripgrep configuration
    if [[ -d "$DOTFILES_DIR/config/ripgrep" ]]; then
        create_symlink "$DOTFILES_DIR/config/ripgrep" "$HOME/.config/ripgrep"
    fi

    # Claude Code configuration (opt-out via DOTFILES_NO_AI_TOOLS=1)
    if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]] && [[ -d "$DOTFILES_DIR/claude-code" ]]; then
        _setup_claude_code
    elif [[ "${DOTFILES_NO_AI_TOOLS:-}" == "1" ]]; then
        log_info "DOTFILES_NO_AI_TOOLS=1, skipping Claude Code setup"
    else
        log_info "Claude Code directory not found, skipping Claude Code setup"
    fi

    # Codex configuration (opt-out via DOTFILES_NO_AI_TOOLS=1)
    if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]] && [[ -d "$DOTFILES_DIR/codex" ]]; then
        _setup_codex
    elif [[ "${DOTFILES_NO_AI_TOOLS:-}" == "1" ]]; then
        log_info "DOTFILES_NO_AI_TOOLS=1, skipping Codex setup"
    fi

    # Copilot CLI configuration (opt-out via DOTFILES_NO_AI_TOOLS=1)
    if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]] && [[ -d "$DOTFILES_DIR/copilot" ]]; then
        _setup_copilot
    fi

    # GitHub CLI credentials (devcontainer persistence only)
    if is_devcontainer && [[ -d "$HOME/.dotfiles-state" ]]; then
        setup_volume_dir "$HOME/.dotfiles-state/gh" "$HOME/.config/gh"
        log_success "$HOME/.config/gh -> volume"
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
