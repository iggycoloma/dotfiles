#!/usr/bin/env zsh
# ~/.zshrc - Zsh interactive shell configuration
# This file runs for every interactive Zsh session (login or non-login)
# For login shells, .zprofile runs first, then this file

# Startup profiling: ZSH_PROFILE=1 zsh -i -c exit
[[ -n "$ZSH_PROFILE" ]] && zmodload zsh/zprof

# CI timing diagnostics (only when CI env var is set)
if [[ -n "$CI" ]]; then
    zmodload zsh/datetime  # Load datetime module for EPOCHREALTIME
    _zsh_start_time=$EPOCHREALTIME
fi

# Dotfiles directory
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# Source shared exports (idempotent -- skipped if .zprofile already loaded them)
if [[ -z "$_DOTFILES_EXPORTS_LOADED" && -f "$DOTFILES_DIR/shell/exports.sh" ]]; then
    source "$DOTFILES_DIR/shell/exports.sh"
fi

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

# Completion system initialization (cached -- full rebuild once per day)
autoload -Uz compinit
_comp_dump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
if [[ -n "$_comp_dump"(#qN.mh+24) ]]; then
    compinit -d "$_comp_dump"
else
    compinit -C -d "$_comp_dump"
fi
unset _comp_dump

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
    [[ -n "$CI" ]] && _before_completions=$EPOCHREALTIME
    source "$DOTFILES_DIR/shell/completion.sh"
    if [[ -n "$CI" ]]; then
        _after_completions=$EPOCHREALTIME
        echo "[CI-TIMING] Completions loaded in $(( (_after_completions - _before_completions) * 1000 ))ms" >&2
    fi
fi

# Load local zshrc customizations (before prompt)
if [[ -f "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi

# Initialize Starship prompt (MUST be last)
# Starship needs the terminal to be fully initialized with COLUMNS set
if command -v starship &> /dev/null; then
    [[ -n "$CI" ]] && _before_starship=$EPOCHREALTIME
    eval "$(starship init zsh)"
    if [[ -n "$CI" ]]; then
        _after_starship=$EPOCHREALTIME
        echo "[CI-TIMING] Starship init in $(( (_after_starship - _before_starship) * 1000 ))ms" >&2
    fi
else
    # Fallback prompt if starship is not available
    PROMPT='%F{green}%n@%m%f:%F{cyan}%~%f%# '
fi

# CI timing summary
if [[ -n "$CI" && -n "$_zsh_start_time" ]]; then
    _zsh_end_time=$EPOCHREALTIME
    echo "[CI-TIMING] Total zsh startup: $(( (_zsh_end_time - _zsh_start_time) * 1000 ))ms" >&2
fi

# Startup profiling output
[[ -n "$ZSH_PROFILE" ]] && zprof
