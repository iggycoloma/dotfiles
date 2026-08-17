#!/usr/bin/env bash
# Symlink management for dotfiles

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

source "$DOTFILES_DIR/bootstrap/logging.sh"
source "$DOTFILES_DIR/bootstrap/detect.sh"

backup_if_exists() {
    local target=$1
    if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_warn "Backing up existing $(basename "$target") to $BACKUP_DIR"
        cp -a "$target" "$BACKUP_DIR/"
        rm -rf "$target"
    elif [[ -L "$target" ]]; then
        rm "$target"
    fi
}

create_symlink() {
    local source=$1
    local target=$2

    if [[ ! -e "$source" ]]; then
        log_error "Source does not exist: $source"
        return 1
    fi

    local target_dir
    target_dir=$(dirname "$target")
    mkdir -p "$target_dir"

    backup_if_exists "$target"
    ln -sf "$source" "$target"
    log_success "Linked $(basename "$source") -> $target"
}

_link_if_present() {
    [[ -e "$1" ]] || return 0
    create_symlink "$1" "$2"
}

# Idempotent. A target that is still a real directory has its contents merged
# into the volume before it is replaced by the link.
setup_volume_dir() {
    local vol_path="$1"
    local target_path="$2"
    mkdir -p "$vol_path"
    if [[ -d "$target_path" ]] && [[ ! -L "$target_path" ]]; then
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

# Directories are removed before copying so files deleted upstream do not
# survive as stale leftovers in the target.
stomp_configs() {
    local source_dir="$1"
    local target_dir="$2"
    shift 2
    local item
    for item in "$@"; do
        local src="$source_dir/$item"
        local dst="$target_dir/$item"
        [[ -e "$src" ]] || continue
        if [[ -d "$src" ]]; then
            rm -rf "$dst"
            cp -rf "$src" "$dst"
        else
            # Older installs symlinked these; drop the link before copying.
            [[ -L "$dst" ]] && rm -f "$dst"
            cp -f "$src" "$dst"
        fi
    done
}

# [include] rather than a symlink so ~/.config/git/config stays a real writable
# file: `git config --global` writes and the host identity VS Code copies into
# devcontainers both land there without dirtying the repo.
_ensure_git_include() {
    local dotfiles_gitconfig="$1"
    local xdg_config="$HOME/.config/git/config"
    mkdir -p "$(dirname "$xdg_config")"

    if [[ -L "$xdg_config" ]]; then
        log_info "Migrating git config from symlink to [include] pattern"
        rm -f "$xdg_config"
    fi

    if [[ -f "$xdg_config" ]] && grep -qF "$dotfiles_gitconfig" "$xdg_config" 2>/dev/null; then
        log_success "Git config already includes dotfiles settings"
        return 0
    fi

    # Prepended, so dotfiles are defaults and user settings below override.
    local tmp
    tmp=$(mktemp)
    printf '[include]\n\tpath = %s\n' "$dotfiles_gitconfig" > "$tmp"
    if [[ -f "$xdg_config" ]]; then
        cat "$xdg_config" >> "$tmp"
    fi
    mv "$tmp" "$xdg_config"
    log_success "Added [include] for dotfiles git settings"
}

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

# No-op on hosts: only devcontainers need the config dir redirected to a volume.
_wire_tool_dir() {
    local state_subdir="$1" target_dir="$2"
    if is_devcontainer && [[ -d "$HOME/.dotfiles-state" ]]; then
        setup_volume_dir "$HOME/.dotfiles-state/$state_subdir" "$target_dir"
        log_success "$target_dir -> state"
    elif is_devcontainer; then
        mkdir -p "$target_dir"
    fi
}

_chmod_hooks() {
    local dir="$1"
    for f in "$dir"/*.sh; do
        [[ -f "$f" ]] && chmod +x "$f"
    done
    # Without this, a hooks dir with no .sh files makes the final loop
    # iteration return 1, and set -e kills whichever caller ran this as the
    # last command of an && list or function body.
    return 0
}

# Containers get a copy so a rebuild always refreshes it; hosts get a symlink
# so edits in the repo take effect live.
_deploy_variant_file() {
    local source_dir="$1"
    local host_name="$2"
    local container_name="$3"
    local target="$4"
    local preserve_existing="${5:-0}"

    if is_devcontainer; then
        local src="$source_dir/$container_name"
        if [[ ! -f "$src" ]]; then
            log_warn "Container variant missing: $src"
            return 0
        fi
        if [[ "$preserve_existing" == "1" ]] && [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
            log_warn "Skipping $target (preserving existing in-container file)"
            return 0
        fi
        # Drop stale symlink (e.g. from a prior host install) before stomping.
        [[ -L "$target" ]] && rm -f "$target"
        mkdir -p "$(dirname "$target")"
        cp -f "$src" "$target"
        log_success "$(basename "$src") -> $target (container variant)"
    else
        local src="$source_dir/$host_name"
        if [[ ! -f "$src" ]]; then
            log_warn "Host variant missing: $src"
            return 0
        fi
        if [[ "$preserve_existing" == "1" ]] && [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
            log_warn "Skipping $target (preserving local edits to host variant)"
            return 0
        fi
        create_symlink "$src" "$target"
    fi
}

# Usage: _deploy_configs source_dir target_dir files... -- directories...
_deploy_configs() {
    local source_dir="$1" target_dir="$2"
    shift 2

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
        # Plain `[[ -d ]] && cmd` returns 1 when the dir is absent, and set -e
        # then kills the whole deploy for tools that ship no hooks dir (copilot).
        if [[ -d "$target_dir/hooks" ]]; then
            _chmod_hooks "$target_dir/hooks"
        fi
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

# Deploy the shared Pushover notify lib alongside the per-tool notify
# hooks in devcontainers. On hosts the notify hooks resolve the lib by
# walking back through their own symlink to <repo>/bootstrap/lib/, so a
# sibling deployment isn't needed -- and would in fact write the lib
# *into the repo* because the tool's hooks dir is itself a symlink into
# the repo on hosts.
_deploy_notify_lib() {
    local target_dir="$1"
    local src="$DOTFILES_DIR/bootstrap/lib/notify-pushover.sh"
    [[ -f "$src" ]] || return 0
    is_devcontainer || return 0
    mkdir -p "$target_dir"
    local target="$target_dir/notify-pushover.sh"
    [[ -L "$target" ]] && rm -f "$target"
    cp -f "$src" "$target"
}

# Shared instruction fragments (agent-prompts/) deployed per tool as
# <tool-config-dir>/prompts. CLAUDE.md pulls them in via @~/.claude/prompts/...
# imports; Codex and Copilot have no import mechanism, so their global files
# instruct the agent to read the deployed copies at session start.
_deploy_agent_prompts() {
    local target="$1"
    [[ -d "$DOTFILES_DIR/agent-prompts" ]] || return 0
    if is_devcontainer; then
        rm -rf "$target"
        cp -rf "$DOTFILES_DIR/agent-prompts" "$target"
    else
        create_symlink "$DOTFILES_DIR/agent-prompts" "$target"
    fi
}

_setup_agent_hooks() {
    [[ -d "$DOTFILES_DIR/agent-hooks" ]] || return 0

    log_info "Setting up shared agent hooks..."

    if is_devcontainer; then
        rm -rf "$HOME/.agent-hooks"
        cp -rf "$DOTFILES_DIR/agent-hooks" "$HOME/.agent-hooks"
        _chmod_hooks "$HOME/.agent-hooks"
        log_success "agent-hooks -> $HOME/.agent-hooks (container copy)"
    else
        _chmod_hooks "$DOTFILES_DIR/agent-hooks"
        create_symlink "$DOTFILES_DIR/agent-hooks" "$HOME/.agent-hooks"
    fi
}

# Deploy one of two variant files as a real managed copy. Use this when a
# follow-up step writes machine-specific local settings into the deployed file.
_deploy_variant_copy() {
    local source_dir="$1"
    local host_name="$2"
    local container_name="$3"
    local target="$4"
    local src

    if is_devcontainer; then
        src="$source_dir/$container_name"
        if [[ ! -f "$src" ]]; then
            log_warn "Container variant missing: $src"
            return 0
        fi
    else
        src="$source_dir/$host_name"
        if [[ ! -f "$src" ]]; then
            log_warn "Host variant missing: $src"
            return 0
        fi
    fi

    [[ -L "$target" ]] && rm -f "$target"
    mkdir -p "$(dirname "$target")"
    cp -f "$src" "$target"
    log_success "$(basename "$src") -> $target (managed copy)"
}

_setup_claude_code() {
    log_info "Setting up Claude Code configuration..."

    _wire_tool_dir "claude" "$HOME/.claude"

    if [[ -f "$HOME/.claude.json" ]] && [[ ! -L "$HOME/.claude.json" ]] && [[ ! -f "$HOME/.claude/config.json" ]]; then
        mv "$HOME/.claude.json" "$HOME/.claude/config.json"
        log_success "Migrated ~/.claude.json -> ~/.claude/config.json"
    fi

    # settings.json: host vs container variant. Hosts get the full Bash sandbox
    # (sandbox.enabled=true, allowedDomains, etc.); containers get
    # sandbox.enabled=false because the container itself is the boundary.
    # See docs/sandbox.md for the three-tier model.
    _deploy_variant_file "$DOTFILES_DIR/claude-code" \
        settings.json settings.container.json \
        "$HOME/.claude/settings.json"

    # Personal Claude Code config. scripts/ and templates/ used to live here
    # but moved to the unattended/ subtree. See _setup_unattended for deployment of
    # the ralph harness, templates, rubric, and egress allowlist.
    _deploy_configs "$DOTFILES_DIR/claude-code" "$HOME/.claude" \
        CLAUDE.md statusline.sh -- hooks agents commands

    _deploy_notify_lib "$HOME/.claude/hooks"

    _deploy_agent_prompts "$HOME/.claude/prompts"

    log_success "Claude Code configuration complete"
}

# Deploy the unattended coding harness to ~/.unattended/. Only runs when
# DOTFILES_INSTALL_UNATTENDED=1 is set (opt-in). Terminal-QoL users never
# see ralph.sh or the devcontainer rubric in their home.
_setup_unattended() {
    log_info "Setting up unattended coding harness (DOTFILES_INSTALL_UNATTENDED=1)..."

    mkdir -p "$HOME/.unattended/lib"

    _deploy_configs "$DOTFILES_DIR/unattended" "$HOME/.unattended" \
        devcontainer-rubric.json egress-allowlist.txt -- scripts templates bootstrap hooks

    # Vendor logging.sh so deployed ralph can source it without DOTFILES_DIR.
    cp -f "$DOTFILES_DIR/bootstrap/logging.sh" "$HOME/.unattended/lib/logging.sh"

    if [[ -d "$HOME/.unattended/scripts" ]]; then
        chmod +x "$HOME/.unattended/scripts"/*.sh 2>/dev/null || true
    fi
    if [[ -d "$HOME/.unattended/bootstrap" ]]; then
        chmod +x "$HOME/.unattended/bootstrap"/*.sh 2>/dev/null || true
    fi

    log_success "Unattended coding harness deployed to ~/.unattended/"
}

_setup_codex() {
    log_info "Setting up Codex configuration..."

    if ! is_devcontainer && [[ -L "$HOME/.codex" ]]; then
        log_warn "Removing old whole-directory symlink ~/.codex (migrating to managed files)"
        rm "$HOME/.codex"
    fi

    _wire_tool_dir "codex" "$HOME/.codex"

    _deploy_configs "$DOTFILES_DIR/codex" "$HOME/.codex" \
        AGENTS.md hooks.json -- hooks

    _deploy_notify_lib "$HOME/.codex/hooks"

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

    # config.toml: host vs container variant. Deploy as a real managed copy in
    # both environments because _setup_codex_notify appends a machine-specific
    # absolute hook path. Symlinking would dirty the tracked source TOML.
    # Containers must also overwrite persisted config so a stale host sandbox
    # mode cannot survive rebuilds.
    _deploy_variant_copy "$DOTFILES_DIR/codex" \
        config.toml config.container.toml \
        "$HOME/.codex/config.toml"

    _setup_codex_notify

    _deploy_agent_prompts "$HOME/.codex/prompts"

    log_success "Codex configuration complete"
}

_setup_copilot() {
    log_info "Setting up Copilot CLI configuration..."

    _wire_tool_dir "copilot" "$HOME/.copilot"

    _deploy_configs "$DOTFILES_DIR/copilot" "$HOME/.copilot" \
        copilot-instructions.md hooks.json

    _deploy_agent_prompts "$HOME/.copilot/prompts"

    log_success "Copilot CLI configuration complete"
}

_setup_codex_notify() {
    [[ -f "$HOME/.codex/hooks/notify.sh" ]] || return 0

    if [[ -f "$HOME/.codex/config.toml" ]]; then
        if grep -q '^notify\s*=\s*"' "$HOME/.codex/config.toml"; then
            log_info "Fixing notify hook format in ~/.codex/config.toml (string -> array)"
            if has_tool sd; then
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

create_symlinks() {
    log_info "Creating symlinks..."

    if is_devcontainer && [[ "${DOTFILES_NO_STATE_PERSISTENCE:-}" != "1" ]]; then
        setup_state_persistence
    elif [[ "${DOTFILES_NO_STATE_PERSISTENCE:-}" == "1" ]]; then
        log_info "DOTFILES_NO_STATE_PERSISTENCE=1, skipping state persistence setup"
    fi

    # Named volumes mount root-owned on first use; without write access here,
    # every state-backed tool config (gh, claude, codex) silently fails to
    # persist.
    if [[ -d "$HOME/.dotfiles-state" ]]; then
        if [[ ! -w "$HOME/.dotfiles-state" ]]; then
            if has_tool sudo; then
                sudo chown -R "$(id -u):$(id -g)" "$HOME/.dotfiles-state" ||
                    log_warn "Could not chown ~/.dotfiles-state (sudo blocked, e.g. no_new_privs); rebuild the container or chown the volume from the host. State persistence may fail."
            else
                log_warn "$HOME/.dotfiles-state is not writable and sudo is unavailable; state persistence may fail"
            fi
        fi
        # chmod only when we own the directory: a non-owner chmod fails with
        # EPERM, which would abort the script under 'set -e'.
        [[ -O "$HOME/.dotfiles-state" ]] && chmod 700 "$HOME/.dotfiles-state"
    fi

    create_symlink "$DOTFILES_DIR/shell/.bashrc" "$HOME/.bashrc"
    create_symlink "$DOTFILES_DIR/shell/.bash_profile" "$HOME/.bash_profile"
    create_symlink "$DOTFILES_DIR/shell/.zshrc" "$HOME/.zshrc"
    create_symlink "$DOTFILES_DIR/shell/.zprofile" "$HOME/.zprofile"

    _ensure_git_include "$DOTFILES_DIR/git/.gitconfig"
    create_symlink "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"
    create_symlink "$DOTFILES_DIR/git/.gitmessage" "$HOME/.gitmessage"

    # This path is what git/.gitconfig sets core.hooksPath to.
    if [[ "${DOTFILES_NO_GIT_HOOKS:-}" != "1" ]] && [[ -d "$DOTFILES_DIR/git/hooks" ]]; then
        for file in "$DOTFILES_DIR/git/hooks"/*; do
            [ -f "$file" ] || continue
            chmod +x "$file" || true
        done
        create_symlink "$DOTFILES_DIR/git/hooks" "$HOME/.config/git/hooks"
    fi

    _link_if_present "$DOTFILES_DIR/vim/.vimrc" "$HOME/.vimrc"

    mkdir -p "$HOME/.config"
    _link_if_present "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"
    for cfg in bat bottom ghostty lazygit yazi ripgrep; do
        _link_if_present "$DOTFILES_DIR/config/$cfg" "$HOME/.config/$cfg"
    done

    if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]]; then
        _setup_agent_hooks
    fi

    if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]] && [[ -d "$DOTFILES_DIR/claude-code" ]]; then
        _setup_claude_code
    elif [[ "${DOTFILES_NO_AI_TOOLS:-}" == "1" ]]; then
        log_info "DOTFILES_NO_AI_TOOLS=1, skipping Claude Code setup"
    else
        log_info "Claude Code directory not found, skipping Claude Code setup"
    fi

    if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]] && [[ -d "$DOTFILES_DIR/codex" ]]; then
        _setup_codex
    elif [[ "${DOTFILES_NO_AI_TOOLS:-}" == "1" ]]; then
        log_info "DOTFILES_NO_AI_TOOLS=1, skipping Codex setup"
    fi

    if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]] && [[ -d "$DOTFILES_DIR/copilot" ]]; then
        _setup_copilot
    fi

    # Opt-in, so terminal-QoL installs never see ralph in their home. The
    # unattended devcontainer profile sets this in containerEnv.
    if [[ "${DOTFILES_INSTALL_UNATTENDED:-0}" == "1" ]] && [[ -d "$DOTFILES_DIR/unattended" ]]; then
        _setup_unattended
    fi

    # Persists forge credentials across rebuilds. Reported per-tool because
    # setup_volume_dir returns 1 when it cannot migrate an existing directory,
    # and an unconditional success line would promise persistence that is about
    # to be lost.
    if is_devcontainer && [[ -d "$HOME/.dotfiles-state" ]]; then
        if setup_volume_dir "$HOME/.dotfiles-state/gh" "$HOME/.config/gh"; then
            log_success "$HOME/.config/gh -> volume"
        else
            log_warn "$HOME/.config/gh not persisted -- gh credentials will not survive a rebuild"
        fi
        if setup_volume_dir "$HOME/.dotfiles-state/glab-cli" "$HOME/.config/glab-cli"; then
            log_success "$HOME/.config/glab-cli -> volume"
        else
            log_warn "$HOME/.config/glab-cli not persisted -- glab credentials will not survive a rebuild"
        fi
    fi

    if ! is_minimal_install; then
        _link_if_present "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
    fi

    _link_if_present "$DOTFILES_DIR/bin" "$HOME/.local/bin/dotfiles-bin"

    log_success "Symlinks created successfully!"
    if [[ -d "$BACKUP_DIR" ]]; then
        log_info "Backups saved to: $BACKUP_DIR"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    create_symlinks
fi
