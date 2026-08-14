#!/usr/bin/env bash
# Environment variables and exports
#
# Sourced by .bashrc (bash) and .zprofile/.zshrc (zsh).
# Safe to source multiple times -- all assignments are idempotent.

# Disable NVM's racy current-version symlink — PATH is managed by nvm.sh directly
export NVM_SYMLINK_CURRENT=false

# Homebrew initialization (macOS)
# Must be done early so Homebrew-installed tools are available
if [[ "$(uname -s)" == "Darwin" ]]; then
    # Detect Homebrew installation path based on architecture
    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        # Apple Silicon (M1/M2/M3)
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x "/usr/local/bin/brew" ]]; then
        # Intel Mac
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# XDG Base Directory Specification
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Editor preferences
if command -v nvim &> /dev/null; then
    export EDITOR="nvim"
    export VISUAL="nvim"
elif command -v vim &> /dev/null; then
    export EDITOR="vim"
    export VISUAL="vim"
else
    export EDITOR="vi"
    export VISUAL="vi"
fi

# Pager
export PAGER="less"
export LESS="-R -F -X"

# History configuration
export HISTSIZE=100000
export HISTFILESIZE=100000
export SAVEHIST=100000
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE="ls:cd:cd -:pwd:exit:date:* --help"

# Language - only set if locale is available
if locale -a 2>/dev/null | grep -qi "en_US.utf8\|en_US.UTF-8"; then
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
elif locale -a 2>/dev/null | grep -qi "C.UTF-8"; then
    export LANG="C.UTF-8"
    export LC_ALL="C.UTF-8"
fi

# Path additions (with dedup guard)
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"
[[ ":$PATH:" != *":$HOME/bin:"* ]] && export PATH="$HOME/bin:$PATH"
# Dev Containers CLI standalone install prefix (hosts only; dir absent in containers)
[[ -d "$HOME/.devcontainers/bin" && ":$PATH:" != *":$HOME/.devcontainers/bin:"* ]] && export PATH="$HOME/.devcontainers/bin:$PATH"

# FZF configuration
export FZF_DEFAULT_OPTS="
    --height 40%
    --layout=reverse
    --border
    --inline-info
    --color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7
    --color=fg+:#c0caf5,bg+:#283457,hl+:#7dcfff
    --color=info:#7aa2f7,prompt:#7dcfff,pointer:#7dcfff
    --color=marker:#9ece6a,spinner:#9ece6a,header:#9ece6a
"

# Use fd or ripgrep for fzf if available
if command -v fd &> /dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"
elif command -v rg &> /dev/null; then
    export FZF_DEFAULT_COMMAND="rg --files --hidden --follow --glob '!.git/*'"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# Bat configuration (syntax highlighting)
export BAT_THEME="OneHalfDark"
export BAT_STYLE="numbers,changes,header"

# EZA colors (modern ls replacement)
# Using bright colors for better visibility on dark backgrounds
export EZA_COLORS="\
di=1;96:\
ex=1;92:\
ln=1;95:\
or=1;31:\
fi=0:\
*.tar=1;33:\
*.zip=1;33:\
*.gz=1;33:\
*.bz2=1;33:\
*.xz=1;33:\
*.7z=1;33:\
*.rar=1;33:\
*.jpg=1;91:\
*.jpeg=1;91:\
*.png=1;91:\
*.gif=1;91:\
*.svg=1;91:\
*.mp4=1;91:\
*.mkv=1;91:\
*.mp3=1;96:\
*.flac=1;96:\
*.wav=1;96:\
*.pdf=1;93:\
*.doc=1;93:\
*.docx=1;93:\
*.md=0;93:\
*.py=0;97:\
*.js=0;97:\
*.ts=0;97:\
*.go=0;97:\
*.rs=0;97:\
*.sh=0;97:\
*.json=0;36:\
*.yaml=0;36:\
*.yml=0;36:\
*.toml=0;36"

# ripgrep configuration
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/config"

# Repo-shipped completions own their command names where carapace collides.
# Carapace's `wt` spec is Windows Terminal (wt.exe), unrelated to bin/wt, and
# its init mass-registers every spec after completion.sh has already bound
# ours -- so last-writer-wins silently replaced `wt` completion. Excluding the
# spec states the ownership rule once instead of re-asserting compdef/complete
# per shell after the carapace source. Must be set before completion.sh runs
# `carapace _carapace <shell>`; both .bashrc and .zprofile source this first.
# Appended, not assigned: a devcontainer remoteEnv or user profile may have
# excluded other specs deliberately, and the guard keeps re-sourcing a no-op.
case ",${CARAPACE_EXCLUDES}," in
    *,wt,*) ;;
    *) export CARAPACE_EXCLUDES="${CARAPACE_EXCLUDES:+$CARAPACE_EXCLUDES,}wt" ;;
esac

# Less colors for man pages
export LESS_TERMCAP_mb=$'\e[1;32m'      # begin bold
export LESS_TERMCAP_md=$'\e[1;34m'      # begin blink
export LESS_TERMCAP_me=$'\e[0m'         # reset bold/blink
export LESS_TERMCAP_so=$'\e[01;33m'     # begin reverse video
export LESS_TERMCAP_se=$'\e[0m'         # reset reverse video
export LESS_TERMCAP_us=$'\e[1;4;31m'    # begin underline
export LESS_TERMCAP_ue=$'\e[0m'         # reset underline

# GPG TTY
GPG_TTY=$(tty)
export GPG_TTY

# Docker BuildKit
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Claude Code: store global config inside ~/.claude dir (persists in devcontainers)
if command -v claude &> /dev/null; then
    export CLAUDE_CONFIG_DIR="$HOME/.claude"
fi

if [[ -f "$HOME/.exports.local" ]]; then
    source "$HOME/.exports.local"
fi
