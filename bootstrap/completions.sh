#!/usr/bin/env bash
# Shell completion setup for bash and zsh

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
source "$DOTFILES_DIR/bootstrap/detect.sh"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}==>${NC} $1"; }
log_success() { echo -e "${GREEN}==>${NC} $1"; }
log_warn() { echo -e "${YELLOW}==>${NC} $1"; }

# Setup bash completions
setup_bash_completions() {
    log_info "Setting up bash completions..."

    local completion_dir="$HOME/.local/share/bash-completion/completions"
    mkdir -p "$completion_dir"

    # Generate completions for tools that support it
    local tools=(
        "gh:github-cli"
        "kubectl:kubernetes"
        "docker:docker"
        "terraform:terraform"
        "aws:aws-cli"
    )

    for tool_pair in "${tools[@]}"; do
        local tool="${tool_pair%%:*}"
        local name="${tool_pair##*:}"

        if has_tool "$tool"; then
            case "$tool" in
                gh)
                    gh completion -s bash > "$completion_dir/gh" 2>/dev/null || true
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

    log_success "Bash completions configured"
}

# Setup zsh completions
setup_zsh_completions() {
    log_info "Setting up zsh completions..."

    # Create zsh config directory
    local zsh_dir="${ZDOTDIR:-$HOME/.config/zsh}"
    mkdir -p "$zsh_dir/completions"

    # Install zsh plugin manager (zinit) if not present
    local zinit_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
    if [[ ! -d "$zinit_dir" ]]; then
        log_info "Installing zinit (zsh plugin manager)..."
        mkdir -p "$(dirname "$zinit_dir")"
        git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$zinit_dir" 2>/dev/null || true
    fi

    # Generate completions for tools
    if has_tool gh; then
        gh completion -s zsh > "$zsh_dir/completions/_gh" 2>/dev/null || true
        log_success "Generated gh completion"
    fi

    if has_tool kubectl; then
        kubectl completion zsh > "$zsh_dir/completions/_kubectl" 2>/dev/null || true
        log_success "Generated kubectl completion"
    fi

    if has_tool docker; then
        # Docker completion usually from system
        :
    fi

    # Create fpath file for zshrc to source
    cat > "$zsh_dir/completions.zsh" <<'EOF'
# Add custom completions to fpath
fpath=("${ZDOTDIR:-$HOME/.config/zsh}/completions" $fpath)

# Load zinit if available
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ -d "$ZINIT_HOME" ]]; then
    source "${ZINIT_HOME}/zinit.zsh"

    # Load fast-syntax-highlighting
    zinit light zdharma-continuum/fast-syntax-highlighting

    # Load zsh-autosuggestions
    zinit light zsh-users/zsh-autosuggestions

    # Load zsh-completions
    zinit light zsh-users/zsh-completions
fi

# Initialize completion system
autoload -Uz compinit
compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION"
EOF

    log_success "Zsh completions configured"
}

# Main setup function
setup_completions() {
    log_info "Setting up shell completions..."

    # Setup for both shells
    setup_bash_completions
    setup_zsh_completions

    log_success "Completion setup complete!"
}

# If run directly, execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_completions
fi
