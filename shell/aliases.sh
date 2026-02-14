#!/usr/bin/env bash
# Command aliases

# Enable color support with custom dircolors for better visibility on dark backgrounds
if [[ -x /usr/bin/dircolors ]]; then
    # Use custom .dircolors from dotfiles if available, otherwise use system default
    if [[ -r "$HOME/.dotfiles/shell/.dircolors" ]]; then
        eval "$(dircolors -b "$HOME/.dotfiles/shell/.dircolors")"
    elif [[ -r ~/.dircolors ]]; then
        eval "$(dircolors -b ~/.dircolors)"
    else
        eval "$(dircolors -b)"
    fi
fi

# Modern replacements
if command -v eza &> /dev/null; then
    alias ls='eza --group-directories-first'
    alias ll='eza -l --group-directories-first --git'
    alias la='eza -la --group-directories-first --git'
    alias lt='eza -T --group-directories-first'
    alias l='eza -lah --group-directories-first --git'
else
    alias ls='ls --color=auto'
    alias ll='ls -lh'
    alias la='ls -lah'
    alias l='ls -lah'
fi


if command -v rg &> /dev/null; then
    if [[ "${DOTFILES_OPINIONATED_ALIASES:-}" == "1" ]]; then
        alias grep='rg'
        alias ggrep='command grep'  # original grep without alias expansion
    else
        # Keep system grep; provide a convenience alias that won't break scripts
        alias rgrep='rg'
    fi
else
    alias grep='grep --color=auto'
fi

if command -v fd &> /dev/null; then
    if [[ "${DOTFILES_OPINIONATED_ALIASES:-}" == "1" ]]; then
        alias find='fd'
        alias ffind='command find'  # original find without alias expansion
    else
        # Keep system find; fd is available directly
        :
    fi
fi

if command -v btm &> /dev/null; then
    alias htop='btm'
elif command -v btop &> /dev/null; then
    alias htop='btop'
fi

if command -v ncdu &> /dev/null; then
    alias du='ncdu --color dark'
fi

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Directory listing shortcuts
alias lsd='ls -d */'          # list only directories
alias lsf='ls -p | grep -v /' # list only files

# Git aliases
alias g='git'
alias gs='git status'
alias gst='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -v'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gpl='git pull'
alias gpr='git pull --rebase'
alias gf='git fetch'
alias gfa='git fetch --all'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias glg='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'
alias gsh='git stash'
alias gshp='git stash pop'
alias gm='git merge'
alias gr='git rebase'
alias gri='git rebase -i'
alias grc='git rebase --continue'
alias gra='git rebase --abort'
alias grh='git reset HEAD'
alias grhh='git reset --hard HEAD'
alias gclean='git clean -fd'

# Lazygit
if command -v lazygit &> /dev/null; then
    alias lg='lazygit'
fi

# Docker aliases
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
# dlogs and dclean are defined as functions in functions.sh for better functionality

# Kubernetes aliases
if command -v kubectl &> /dev/null; then
    alias k='kubectl'
    alias kgp='kubectl get pods'
    alias kgs='kubectl get services'
    alias kgd='kubectl get deployments'
    alias kgn='kubectl get nodes'
    alias kdp='kubectl describe pod'
    alias kds='kubectl describe service'
    alias kdd='kubectl describe deployment'
    alias klogs='kubectl logs -f'
    alias kex='kubectl exec -it'
fi

# Python aliases
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'
alias activate='source venv/bin/activate'

# Quick edits
alias reload='exec $SHELL -l'
if [[ -n "${ZSH_VERSION:-}" ]]; then
    alias src='source ~/.zshrc'
else
    alias src='source ~/.bashrc'
fi

# System
# ports, myip, weather implemented as functions with timeouts in functions.sh

# Safety nets
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'

# Shortcuts
alias h='history'
alias j='jobs -l'
alias c='clear'
alias q='exit'

alias cclog="$HOME/.dotfiles/claude-code/hooks/query-tool-logs.sh"

# Codex CLI shortcuts
if command -v codex &> /dev/null; then
    alias cx='codex'
    alias cxe='codex exec'
    alias cxr='codex review --uncommitted'
fi

# Load local aliases last so they can override anything above
if [[ -f "$HOME/.aliases.local" ]]; then
    source "$HOME/.aliases.local"
fi
