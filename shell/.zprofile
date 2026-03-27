#!/usr/bin/env zsh
# ~/.zprofile - Zsh login shell configuration
# This file runs once at login for interactive login shells
# Zsh automatically loads .zshrc after this file

# Homebrew initialization (macOS only)
# Must be done early so Homebrew-installed tools are in PATH
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

# PATH additions
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# Nix package manager (sourced after PATH so Nix-installed tools take precedence)
if [[ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
elif [[ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]]; then
    . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
fi

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

# Pager configuration
export PAGER="less"
export LESS="-R -F -X"

# Language - only set if locale is available
if locale -a 2>/dev/null | grep -qi "en_US.utf8\|en_US.UTF-8"; then
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
elif locale -a 2>/dev/null | grep -qi "C.UTF-8"; then
    export LANG="C.UTF-8"
    export LC_ALL="C.UTF-8"
fi

# GPG TTY
export GPG_TTY=$(tty)

# Docker BuildKit
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Tool-specific environment variables
export BAT_THEME="OneHalfDark"
export BAT_STYLE="numbers,changes,header"

export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/config"

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

# FZF commands (use fd or ripgrep if available)
if command -v fd &> /dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"
elif command -v rg &> /dev/null; then
    export FZF_DEFAULT_COMMAND="rg --files --hidden --follow --glob '!.git/*'"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# EZA colors (modern ls replacement)
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

# Less colors for man pages
export LESS_TERMCAP_mb=$'\e[1;32m'      # begin bold
export LESS_TERMCAP_md=$'\e[1;34m'      # begin blink
export LESS_TERMCAP_me=$'\e[0m'         # reset bold/blink
export LESS_TERMCAP_so=$'\e[01;33m'     # begin reverse video
export LESS_TERMCAP_se=$'\e[0m'         # reset reverse video
export LESS_TERMCAP_us=$'\e[1;4;31m'    # begin underline
export LESS_TERMCAP_ue=$'\e[0m'         # reset underline

# Load local zprofile if it exists
if [[ -f "$HOME/.zprofile.local" ]]; then
    source "$HOME/.zprofile.local"
fi
