#!/usr/bin/env zsh
# ~/.zprofile - Zsh login shell configuration

# Source .zshrc if it exists
if [[ -f "$HOME/.zshrc" ]]; then
    source "$HOME/.zshrc"
fi

# Load local zprofile if it exists
if [[ -f "$HOME/.zprofile.local" ]]; then
    source "$HOME/.zprofile.local"
fi
