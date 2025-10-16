#!/usr/bin/env bash
# Shell completion initialization

# This file is sourced by both .bashrc and .zshrc to initialize completions

if [[ -n "$BASH_VERSION" ]]; then
    # Bash completion setup

    # Load bash-completion if available
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        . /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        . /etc/bash_completion
    elif [[ -f /usr/local/etc/bash_completion ]]; then
        . /usr/local/etc/bash_completion
    fi

    # Load custom completions from ~/.local/share
    if [[ -d "$HOME/.local/share/bash-completion/completions" ]]; then
        for completion in "$HOME/.local/share/bash-completion/completions"/*; do
            [[ -f "$completion" ]] && source "$completion"
        done
    fi

    # Tool-specific completions
    if command -v gh &> /dev/null; then
        eval "$(gh completion -s bash 2>/dev/null)"
    fi

    if command -v kubectl &> /dev/null; then
        source <(kubectl completion bash 2>/dev/null)
        complete -F __start_kubectl k  # alias completion
    fi

    if command -v docker &> /dev/null && [[ -f /usr/share/bash-completion/completions/docker ]]; then
        source /usr/share/bash-completion/completions/docker
    fi

    if command -v terraform &> /dev/null; then
        complete -C "$(which terraform)" terraform
    fi

elif [[ -n "$ZSH_VERSION" ]]; then
    # Zsh completion setup

    # Load completions config
    local zsh_config="${ZDOTDIR:-$HOME/.config/zsh}"
    if [[ -f "$zsh_config/completions.zsh" ]]; then
        source "$zsh_config/completions.zsh"
    fi
fi

# Tool initializations (both bash and zsh)

# fzf key bindings and completion
if command -v fzf &> /dev/null; then
    if [[ -n "$BASH_VERSION" ]]; then
        if [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
            source /usr/share/doc/fzf/examples/key-bindings.bash
        elif [[ -f /usr/share/fzf/key-bindings.bash ]]; then
            source /usr/share/fzf/key-bindings.bash
        elif [[ -f ~/.fzf.bash ]]; then
            source ~/.fzf.bash
        fi

        if [[ -f /usr/share/doc/fzf/examples/completion.bash ]]; then
            source /usr/share/doc/fzf/examples/completion.bash
        elif [[ -f /usr/share/fzf/completion.bash ]]; then
            source /usr/share/fzf/completion.bash
        fi
    elif [[ -n "$ZSH_VERSION" ]]; then
        if [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
            source /usr/share/doc/fzf/examples/key-bindings.zsh
        elif [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
            source /usr/share/fzf/key-bindings.zsh
        elif [[ -f ~/.fzf.zsh ]]; then
            source ~/.fzf.zsh
        fi

        if [[ -f /usr/share/doc/fzf/examples/completion.zsh ]]; then
            source /usr/share/doc/fzf/examples/completion.zsh
        elif [[ -f /usr/share/fzf/completion.zsh ]]; then
            source /usr/share/fzf/completion.zsh
        fi
    fi
fi

# zoxide (smart cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init "$(basename "$SHELL")")"
fi

# direnv (directory environment)
if command -v direnv &> /dev/null; then
    eval "$(direnv hook "$(basename "$SHELL")")"
fi

# starship prompt
if command -v starship &> /dev/null; then
    eval "$(starship init "$(basename "$SHELL")")"
fi
