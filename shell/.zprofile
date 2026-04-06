#!/usr/bin/env zsh
# ~/.zprofile - Zsh login shell configuration
# This file runs once at login for interactive login shells
# Zsh automatically loads .zshrc after this file

# Dotfiles directory -- resolve from symlink target if available
if [[ -z "${DOTFILES_DIR:-}" ]]; then
    if [[ -L "$HOME/.zshrc" ]]; then
        DOTFILES_DIR="$(cd "$(dirname "$(readlink "$HOME/.zshrc")")/.." && pwd)"
    else
        DOTFILES_DIR="$HOME/.dotfiles"
    fi
fi
export DOTFILES_DIR

# Source shared environment variables
if [[ -f "$DOTFILES_DIR/shell/exports.sh" ]]; then
    source "$DOTFILES_DIR/shell/exports.sh"
fi

# Load local zprofile if it exists
if [[ -f "$HOME/.zprofile.local" ]]; then
    source "$HOME/.zprofile.local"
fi
