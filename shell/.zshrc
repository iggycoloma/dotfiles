#!/usr/bin/env zsh
# ~/.zshrc - Zsh interactive shell configuration
# This file runs for every interactive Zsh session (login or non-login)
# For login shells, .zprofile runs first, then this file

# Dotfiles directory
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# History configuration
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "$(dirname "$HISTFILE")"
HISTSIZE=100000
SAVEHIST=100000

# History options
setopt HIST_IGNORE_ALL_DUPS  # Don't record duplicates
setopt HIST_IGNORE_SPACE     # Don't record commands starting with space
setopt HIST_REDUCE_BLANKS    # Remove superfluous blanks
setopt HIST_VERIFY           # Show command with history expansion before running
setopt SHARE_HISTORY         # Share history between sessions
setopt EXTENDED_HISTORY      # Record timestamp of command

# Zsh shell options
setopt AUTO_CD               # cd by typing directory name
setopt AUTO_PUSHD            # Push directories onto stack
setopt PUSHD_IGNORE_DUPS     # Don't push duplicates
setopt PUSHD_SILENT          # Don't print directory stack
setopt CORRECT               # Spelling correction for commands
setopt INTERACTIVE_COMMENTS  # Allow comments in interactive mode
setopt EXTENDED_GLOB         # Extended globbing
setopt NO_BEEP               # No beeping

# Completion system initialization
autoload -Uz compinit
compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"

# Completion configuration
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- no matches found --%f'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"

# Ensure cache directories exist
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# Source aliases and functions
if [[ -f "$DOTFILES_DIR/shell/aliases.sh" ]]; then
    source "$DOTFILES_DIR/shell/aliases.sh"
fi

if [[ -f "$DOTFILES_DIR/shell/functions.sh" ]]; then
    source "$DOTFILES_DIR/shell/functions.sh"
fi

# Source tool initialization and completions
if [[ -f "$DOTFILES_DIR/shell/completion.sh" ]]; then
    source "$DOTFILES_DIR/shell/completion.sh"
fi

# Load local zshrc customizations (before prompt)
if [[ -f "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi

# Initialize Starship prompt (MUST be last)
# Starship needs the terminal to be fully initialized with COLUMNS set
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
else
    # Fallback prompt if starship is not available
    PROMPT='%F{green}%n@%m%f:%F{cyan}%~%f%# '
fi
