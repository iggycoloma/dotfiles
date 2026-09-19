#!/usr/bin/env bash
# ~/.bash_profile - Bash login shell configuration

# User-local binaries. Non-interactive login shells never reach ~/.profile,
# and ~/.bashrc returns early when not interactive, so set this here.
if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    PATH="$HOME/.local/bin:$PATH"
fi
export PATH

# Claude Code config dir. ~/.bashrc returns early when non-interactive, so exports.sh
# is never reached in a login shell -- set it here so bash login shells agree with zsh.
export CLAUDE_CONFIG_DIR="$HOME/.claude"

# Source .bashrc if it exists
if [[ -f "$HOME/.bashrc" ]]; then
    source "$HOME/.bashrc"
fi

# Load local bash_profile if it exists
if [[ -f "$HOME/.bash_profile.local" ]]; then
    source "$HOME/.bash_profile.local"
fi
