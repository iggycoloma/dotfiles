#!/usr/bin/env bash
# Useful shell functions

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1" || return 1
}

# Extract various archive formats
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Kill process on specific port
killport() {
    if [ -z "$1" ]; then
        echo "Usage: killport <port>"
        return 1
    fi
    lsof -ti:"$1" | xargs kill -9 2>/dev/null || echo "No process found on port $1"
}

# Delete merged git branches
gbdm() {
    git branch --merged | grep -v '\*\|main\|master\|develop' | xargs -n 1 git branch -d
}

# Checkout git branch with fzf
gcof() {
    if ! command -v fzf &> /dev/null; then
        echo "fzf is not installed"
        return 1
    fi
    local branch
    branch=$(git branch --all | grep -v HEAD | fzf --preview 'git log --oneline --graph --date=short --pretty="format:%C(auto)%cd %h%d %s" $(sed s/^..// <<< {} | cut -d" " -f1)' | sed "s/.* //" | sed "s#remotes/origin/##")
    if [[ -n "$branch" ]]; then
        git checkout "$branch"
    fi
}

# Git log with fzf preview
glf() {
    if ! command -v fzf &> /dev/null; then
        echo "fzf is not installed"
        return 1
    fi
    git log --oneline --decorate --color=always | \
        fzf --ansi --no-sort --reverse --tiebreak=index \
            --preview 'git show --color=always {1}' \
            --bind "enter:execute(git show {1} | less -R)"
}

# Create timestamped backup of file or directory
backup() {
    if [ -z "$1" ]; then
        echo "Usage: backup <file_or_directory>"
        return 1
    fi
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    cp -r "$1" "${1}_backup_${timestamp}"
    echo "Backup created: ${1}_backup_${timestamp}"
}

# Serve current directory over HTTP
serve() {
    local port="${1:-8000}"
    if command -v python3 &> /dev/null; then
        python3 -m http.server "$port"
    elif command -v python &> /dev/null; then
        python -m SimpleHTTPServer "$port"
    else
        echo "Python is not installed"
        return 1
    fi
}

# Find file by name
ff() {
    if command -v fd &> /dev/null; then
        fd "$@"
    else
        find . -type f -iname "*$1*"
    fi
}

# Find directory by name
fd_dir() {
    if command -v fd &> /dev/null; then
        fd --type d "$@"
    else
        find . -type d -iname "*$1*"
    fi
}

# Search file contents
search() {
    if command -v rg &> /dev/null; then
        rg "$@"
    else
        grep -r "$@" .
    fi
}

# Git clone and cd into directory
gcl() {
    if [ -z "$1" ]; then
        echo "Usage: gcl <repository_url>"
        return 1
    fi
    git clone "$1" && cd "$(basename "$1" .git)" || return 1
}

# Create GitHub PR from current branch
# Note: gpr alias already exists in aliases.sh for 'git pull --rebase'
# This function uses a different name to avoid conflict
ghpr() {
    if command -v gh &> /dev/null; then
        gh pr create --web
    else
        echo "GitHub CLI (gh) is not installed"
        return 1
    fi
}

# Note: weather alias already exists in aliases.sh

# Show disk usage for current directory
usage() {
    if command -v dust &> /dev/null; then
        dust
    elif command -v ncdu &> /dev/null; then
        ncdu --color dark
    else
        du -sh * | sort -h
    fi
}

# Quick note taking
note() {
    local notes_dir="$HOME/notes"
    mkdir -p "$notes_dir"
    local note_file="$notes_dir/$(date +%Y-%m-%d).md"

    if [ -n "$1" ]; then
        echo "$(date +%H:%M:%S) - $*" >> "$note_file"
    else
        ${EDITOR:-vi} "$note_file"
    fi
}

# Docker cleanup helpers
dclean() {
    echo "Cleaning up Docker resources..."
    docker container prune -f
    docker image prune -f
    docker volume prune -f
    docker network prune -f
    echo "Docker cleanup complete"
}

# Kill all Docker containers
dkill() {
    docker ps -q | xargs -r docker kill
}

# Show docker container logs with fzf
dlogs() {
    if ! command -v fzf &> /dev/null; then
        echo "fzf is not installed"
        return 1
    fi
    local container
    container=$(docker ps --format '{{.Names}}' | fzf)
    if [[ -n "$container" ]]; then
        docker logs -f "$container"
    fi
}

# Quick chmod shortcuts
chmodx() {
    chmod +x "$@"
}

# Create and enter a temporary directory
tmp() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    cd "$tmp_dir" || return 1
    echo "Created temp directory: $tmp_dir"
}

# Load local functions if they exist
if [[ -f "$HOME/.functions.local" ]]; then
    source "$HOME/.functions.local"
fi
