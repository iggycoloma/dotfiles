#!/usr/bin/env zsh
# ~/.zshrc - Zsh shell configuration

# Dotfiles directory
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# XDG directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Zsh config directory
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"
mkdir -p "$ZDOTDIR"

# History configuration
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "$(dirname "$HISTFILE")"
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_ALL_DUPS  # Don't record duplicates
setopt HIST_IGNORE_SPACE     # Don't record commands starting with space
setopt HIST_REDUCE_BLANKS    # Remove superfluous blanks
setopt HIST_VERIFY           # Show command with history expansion before running
setopt SHARE_HISTORY         # Share history between sessions
setopt EXTENDED_HISTORY      # Record timestamp of command

# Zsh options
setopt AUTO_CD               # cd by typing directory name
setopt AUTO_PUSHD            # Push directories onto stack
setopt PUSHD_IGNORE_DUPS     # Don't push duplicates
setopt PUSHD_SILENT          # Don't print directory stack
setopt CORRECT               # Spelling correction for commands
setopt INTERACTIVE_COMMENTS  # Allow comments in interactive mode
setopt EXTENDED_GLOB         # Extended globbing
setopt NO_BEEP               # No beeping

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

# Colored completion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Menu selection
zstyle ':completion:*' menu select

# Group results by category
zstyle ':completion:*' group-name ''

# Description format
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'

# Warning format
zstyle ':completion:*:warnings' format '%F{red}-- no matches found --%f'

# Enable completion caching
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"
mkdir -p "$XDG_CACHE_HOME/zsh"

# Source shared configuration
if [[ -f "$DOTFILES_DIR/shell/exports.sh" ]]; then
    source "$DOTFILES_DIR/shell/exports.sh"
fi

if [[ -f "$DOTFILES_DIR/shell/aliases.sh" ]]; then
    source "$DOTFILES_DIR/shell/aliases.sh"
fi

if [[ -f "$DOTFILES_DIR/shell/functions.sh" ]]; then
    source "$DOTFILES_DIR/shell/functions.sh"
fi

# Source completions and tool initialization
if [[ -f "$DOTFILES_DIR/shell/completion.sh" ]]; then
    source "$DOTFILES_DIR/shell/completion.sh"
fi

# Fallback prompt if starship is not available
if ! command -v starship &> /dev/null; then
    # Simple colored prompt with bright colors for visibility on dark backgrounds
    PROMPT='%F{green}%n@%m%f:%F{cyan}%~%f%# '
fi

# Load local zshrc if it exists
if [[ -f "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi
