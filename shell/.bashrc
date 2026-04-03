#!/usr/bin/env bash
# ~/.bashrc - Bash shell configuration

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Dotfiles directory
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

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

# Bash-specific configuration
shopt -s checkwinsize  # Update window size after each command
shopt -s histappend    # Append to history file, don't overwrite
shopt -s cmdhist       # Save multi-line commands as one history entry
shopt -s cdspell       # Autocorrect typos in cd commands
shopt -s dirspell      # Autocorrect directory names during completion
shopt -s nocaseglob    # Case-insensitive globbing
shopt -s autocd 2>/dev/null || true  # cd by typing directory name (if supported)

# History configuration
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=100000
HISTFILESIZE=100000
# Prepend history sync; strip any trailing semicolons from existing value to
# avoid ";;" syntax errors when other tools append to PROMPT_COMMAND later.
_existing_prompt_cmd="${PROMPT_COMMAND%;}"
_existing_prompt_cmd="${_existing_prompt_cmd% }"
PROMPT_COMMAND="history -a; history -c; history -r${_existing_prompt_cmd:+; $_existing_prompt_cmd}"
unset _existing_prompt_cmd

# Enable programmable completion
if ! shopt -oq posix; then
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        . /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        . /etc/bash_completion
    fi
fi

# Source completions and tool initialization
if [[ -f "$DOTFILES_DIR/shell/completion.sh" ]]; then
    source "$DOTFILES_DIR/shell/completion.sh"
fi

# Load local bashrc if it exists (before prompt)
if [[ -f "$HOME/.bashrc.local" ]]; then
    source "$HOME/.bashrc.local"
fi

# Initialize Starship prompt (MUST be last)
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
else
    # Fallback prompt if starship is not available
    # Format: bright-green user@host : bright-cyan directory $
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;96m\]\w\[\033[00m\]\$ '
fi
