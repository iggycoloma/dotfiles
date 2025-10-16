#!/usr/bin/env bash
# ~/.bash_profile - Bash login shell configuration

# Source .bashrc if it exists
if [[ -f "$HOME/.bashrc" ]]; then
    source "$HOME/.bashrc"
fi

# Load local bash_profile if it exists
if [[ -f "$HOME/.bash_profile.local" ]]; then
    source "$HOME/.bash_profile.local"
fi
