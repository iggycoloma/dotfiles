#!/usr/bin/env bash
# Shell completion setup for bash and zsh

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/bootstrap/detect.sh"

source "$DOTFILES_DIR/bootstrap/logging.sh"

setup_bash_completions() {
    log_info "Setting up bash completions..."

    local completion_dir="$HOME/.local/share/bash-completion/completions"
    mkdir -p "$completion_dir"

    local tools=(
        "gh:github-cli"
        "glab:gitlab-cli"
        "kubectl:kubernetes"
        "docker:docker"
        "terraform:terraform"
        "aws:aws-cli"
    )

    for tool_pair in "${tools[@]}"; do
        local tool="${tool_pair%%:*}"

        if has_tool "$tool"; then
            case "$tool" in
                gh)
                    gh completion -s bash > "$completion_dir/gh" 2>/dev/null || true
                    ;;
                glab)
                    glab completion -s bash > "$completion_dir/glab" 2>/dev/null || true
                    ;;
                kubectl)
                    kubectl completion bash > "$completion_dir/kubectl" 2>/dev/null || true
                    ;;
                docker)
                    # Docker completion is usually system-provided
                    :
                    ;;
                terraform)
                    terraform -install-autocomplete 2>/dev/null || true
                    ;;
                aws)
                    # AWS CLI v2 has built-in completion
                    :
                    ;;
            esac
            log_success "Generated completion for $tool"
        fi
    done

    # Repo-shipped completions are symlinked, not generated: editing the
    # file in shell/completions/ takes effect in the next shell without
    # re-running the installer.
    ln -sf "$DOTFILES_DIR/shell/completions/wt.bash" "$completion_dir/wt"
    log_success "Linked completion for wt"

    log_success "Bash completions configured"
}

setup_zsh_completions() {
    log_info "Setting up zsh completions..."

    local zsh_dir="${ZDOTDIR:-$HOME/.config/zsh}"
    mkdir -p "$zsh_dir/completions"

    # Install zsh plugin manager (zinit) if not present
    local zinit_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
    if [[ ! -d "$zinit_dir" ]]; then
        log_info "Installing zinit (zsh plugin manager)..."
        mkdir -p "$(dirname "$zinit_dir")"
        git clone --depth 1 --branch v3.9.0 https://github.com/zdharma-continuum/zinit.git "$zinit_dir" 2>/dev/null || true
    fi

    if has_tool gh; then
        gh completion -s zsh > "$zsh_dir/completions/_gh" 2>/dev/null || true
        zsh -c "zcompile '$zsh_dir/completions/_gh'" 2>/dev/null || true
        log_success "Generated gh completion"
    fi

    if has_tool glab; then
        glab completion -s zsh > "$zsh_dir/completions/_glab" 2>/dev/null || true
        zsh -c "zcompile '$zsh_dir/completions/_glab'" 2>/dev/null || true
        log_success "Generated glab completion"
    fi

    # Not zcompiled, unlike the generated completions above: a .zwc beside a
    # symlink into the repo goes stale the moment the source file is edited.
    ln -sf "$DOTFILES_DIR/shell/completions/_wt" "$zsh_dir/completions/_wt"
    log_success "Linked wt completion"

    if has_tool kubectl; then
        kubectl completion zsh > "$zsh_dir/completions/_kubectl" 2>/dev/null || true
        zsh -c "zcompile '$zsh_dir/completions/_kubectl'" 2>/dev/null || true
        log_success "Generated kubectl completion"
    fi

    if has_tool docker; then
        # Docker completion usually from system
        :
    fi

    cat > "$zsh_dir/completions.zsh" <<'EOF'
# Add custom completions to fpath
fpath=("${ZDOTDIR:-$HOME/.config/zsh}/completions" $fpath)

# Load zinit if available (with turbo mode for instant startup)
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ -d "$ZINIT_HOME" ]]; then
    source "${ZINIT_HOME}/zinit.zsh"

    # Load plugins with turbo mode (wait'0' defers until after prompt)
    # This makes zsh startup instant while plugins load in background
    zinit ice wait'0' lucid
    zinit light zdharma-continuum/fast-syntax-highlighting

    zinit ice wait'0' lucid
    zinit light zsh-users/zsh-autosuggestions

    zinit ice wait'0' lucid
    zinit light zsh-users/zsh-completions
fi
EOF

    if has_tool zsh; then
        zsh -c "zcompile '$zsh_dir/completions.zsh'" 2>/dev/null || true
    fi

    # A dump written before the completions above was installed still binds the
    # old set, and `compinit -C` replays it verbatim. Dropping it makes the next
    # shell do a full scan. Path must match .zshrc's _comp_dump.
    local comp_dump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
    rm -f "$comp_dump" "$comp_dump.zwc"

    log_success "Zsh completions configured"
}

setup_completions() {
    log_info "Setting up shell completions..."

    setup_bash_completions
    setup_zsh_completions

    log_success "Completion setup complete!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_completions
fi
