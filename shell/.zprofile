#!/usr/bin/env zsh
# ~/.zprofile - Zsh login shell configuration
# This file runs once at login for interactive login shells
# Zsh automatically loads .zshrc after this file

# Dotfiles directory (needed before sourcing exports.sh)
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# Source shared environment variables
if [[ -f "$DOTFILES_DIR/shell/exports.sh" ]]; then
    source "$DOTFILES_DIR/shell/exports.sh"
fi

# Load local zprofile if it exists
if [[ -f "$HOME/.zprofile.local" ]]; then
    source "$HOME/.zprofile.local"
fi
