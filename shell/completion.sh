#!/usr/bin/env bash
# Shell completion initialization

# This file is sourced by both .bashrc and .zshrc to initialize completions

if [[ -n "$BASH_VERSION" ]]; then
    # Bash completion setup

    # Load bash-completion if available (skip in POSIX mode)
    if ! shopt -oq posix; then
        if [[ -f /usr/share/bash-completion/bash_completion ]]; then
            . /usr/share/bash-completion/bash_completion
        elif [[ -f /etc/bash_completion ]]; then
            . /etc/bash_completion
        elif [[ -f /usr/local/etc/bash_completion ]]; then
            . /usr/local/etc/bash_completion
        fi
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

    # Load completions config (includes zinit plugin manager)
    zsh_config="${ZDOTDIR:-$HOME/.config/zsh}"
    if [[ -f "$zsh_config/completions.zsh" ]]; then
        [[ -n "$CI" ]] && _before_zinit=$EPOCHREALTIME
        source "$zsh_config/completions.zsh"
        if [[ -n "$CI" ]]; then
            _after_zinit=$EPOCHREALTIME
            echo "[CI-TIMING] Zinit + plugins loaded in $(( (_after_zinit - _before_zinit) * 1000 ))ms" >&2
        fi
    fi
fi

# Tool initializations (both bash and zsh)

# fzf key bindings and completion
if command -v fzf &> /dev/null; then
    [[ -n "$CI" ]] && _before_fzf=$EPOCHREALTIME
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
    if [[ -n "$CI" ]]; then
        _after_fzf=$EPOCHREALTIME
        echo "[CI-TIMING] FZF initialization in $(( (_after_fzf - _before_fzf) * 1000 ))ms" >&2
    fi
fi

# zoxide (smart cd) -- deferred on zsh (first prompt), eager on bash
if command -v zoxide &> /dev/null; then
    [[ -n "$CI" ]] && _before_zoxide=$EPOCHREALTIME
    if [[ -n "$ZSH_VERSION" ]]; then
        # Deferred: init on first prompt so tracking hooks are active early
        _zoxide_lazy_init() {
            precmd_functions=("${precmd_functions[@]:#_zoxide_lazy_init}")
            eval "$(zoxide init zsh)"
        }
        precmd_functions+=(_zoxide_lazy_init)
    else
        eval "$(zoxide init bash)"
    fi
    if [[ -n "$CI" ]]; then
        _after_zoxide=$EPOCHREALTIME
        echo "[CI-TIMING] Zoxide init in $(( (_after_zoxide - _before_zoxide) * 1000 ))ms" >&2
    fi
fi

# bash-preexec (required for atuin on bash; zsh has native preexec/precmd)
if [[ -n "$BASH_VERSION" && -f "$HOME/.bash-preexec.sh" ]]; then
    source "$HOME/.bash-preexec.sh"
fi

# atuin (shell history with SQLite)
if command -v atuin &> /dev/null; then
    [[ -n "$CI" && -n "${EPOCHREALTIME+x}" ]] && _before_atuin=$EPOCHREALTIME
    eval "$(atuin init "$(basename "$SHELL")")"
    if [[ -n "$CI" && -n "${EPOCHREALTIME+x}" ]]; then
        _after_atuin=$EPOCHREALTIME
        echo "[CI-TIMING] Atuin init in $(( (_after_atuin - _before_atuin) * 1000 ))ms" >&2
    fi
fi

# direnv (directory environment) -- lazy-load on zsh, eager on bash
if command -v direnv &> /dev/null; then
    [[ -n "$CI" ]] && _before_direnv=$EPOCHREALTIME
    if [[ -n "$ZSH_VERSION" ]]; then
        # Deferred: init on first prompt via precmd hook, then remove itself
        _direnv_lazy_init() {
            precmd_functions=("${precmd_functions[@]:#_direnv_lazy_init}")
            eval "$(direnv hook zsh)"
        }
        precmd_functions+=(_direnv_lazy_init)
    else
        eval "$(direnv hook bash)"
    fi
    if [[ -n "$CI" ]]; then
        _after_direnv=$EPOCHREALTIME
        echo "[CI-TIMING] Direnv init in $(( (_after_direnv - _before_direnv) * 1000 ))ms" >&2
    fi
fi

# Note: Starship prompt initialization moved to .zshrc
# This is because it needs COLUMNS to be set, which happens after .zprofile completes
