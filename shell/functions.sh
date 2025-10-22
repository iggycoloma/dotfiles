#!/usr/bin/env bash
# Useful shell functions

# Create directory and cd into it
function mkcd {
    mkdir -p "$1" && cd "$1" || return 1
}

# Extract various archive formats
function extract {
    if [[ -f "$1" ]]; then
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
function killport {
    if [[ -z "$1" ]]; then
        echo "Usage: killport <port>"
        return 1
    fi
    local port="$1"
    # Prefer fuser when available (often present in containers)
    if command -v fuser &>/dev/null; then
        (fuser -k "${port}/tcp" 2>/dev/null || fuser -k "${port}/udp" 2>/dev/null) && return 0
    fi
    # Fallback to lsof
    if command -v lsof &>/dev/null; then
        lsof -ti:"${port}" 2>/dev/null | grep . | xargs kill -9 2>/dev/null && return 0
    fi
    # Last resort: parse ss output for PIDs
    if command -v ss &>/dev/null; then
        ss -lptnH "( sport = :${port} )" 2>/dev/null | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | grep . | xargs kill -9 2>/dev/null && return 0
    fi
    echo "No process found or unable to terminate processes on port ${port}"
}

# Delete merged git branches
function gbdm {
    git branch --merged | grep -v '\*\|main\|master\|develop' | xargs -n 1 git branch -d
}

# Checkout git branch with fzf
function gcof {
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
function glf {
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
function backup {
    if [[ -z "$1" ]]; then
        echo "Usage: backup <file_or_directory>"
        return 1
    fi
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    cp -r "$1" "${1}_backup_${timestamp}"
    echo "Backup created: ${1}_backup_${timestamp}"
}

# Serve current directory over HTTP
function serve {
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
function ff {
    if command -v fd &> /dev/null; then
        fd "$@"
    else
        find . -type f -iname "*$1*"
    fi
}

# Find directory by name
function fd_dir {
    if command -v fd &> /dev/null; then
        fd --type d "$@"
    else
        find . -type d -iname "*$1*"
    fi
}

# Search file contents
function search {
    if command -v rg &> /dev/null; then
        rg "$@"
    else
        grep -r "$@" .
    fi
}

# Git clone and cd into directory
function gcl {
    if [[ -z "$1" ]]; then
        echo "Usage: gcl <repository_url>"
        return 1
    fi
    git clone "$1" && cd "$(basename "$1" .git)" || return 1
}

# Create GitHub PR from current branch
# Note: gpr alias already exists in aliases.sh for 'git pull --rebase'
# This function uses a different name to avoid conflict
function ghpr {
    if command -v gh &> /dev/null; then
        gh pr create --web
    else
        echo "GitHub CLI (gh) is not installed"
        return 1
    fi
}

# Note: weather alias already exists in aliases.sh

# Show disk usage for current directory
function usage {
    if command -v dust &> /dev/null; then
        dust
    elif command -v ncdu &> /dev/null; then
        ncdu --color dark
    else
        du -sh ./* 2>/dev/null | sort -h
    fi
}

# Quick note taking
function note {
    local notes_dir="$HOME/notes"
    mkdir -p "$notes_dir"
    local note_file="$notes_dir/$(date +%Y-%m-%d).md"

    if [[ -n "$1" ]]; then
        echo "$(date +%H:%M:%S) - $*" >> "$note_file"
    else
        ${EDITOR:-vi} "$note_file"
    fi
}

# Docker cleanup helpers
function dclean {
    echo "Cleaning up Docker resources..."
    docker container prune -f
    docker image prune -f
    docker volume prune -f
    docker network prune -f
    echo "Docker cleanup complete"
}

# Kill all Docker containers
function dkill {
    docker ps -q | grep . | xargs docker kill
}

# Show docker container logs with fzf
function dlogs {
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

# List listening ports and connections (portable)
function ports {
    if command -v ss &>/dev/null; then
        ss -tulpen 2>/dev/null || ss -tuln
        return
    fi
    if command -v netstat &>/dev/null; then
        netstat -tulanp 2>/dev/null || netstat -tuln
        return
    fi
    if command -v lsof &>/dev/null; then
        lsof -i -P -n
        return
    fi
    echo "No network utility found (ss/netstat/lsof)"
    return 1
}

# External helpers with timeouts
function myip {
    local endpoint="${1:-https://ifconfig.me}"
    curl -m 5 -s "$endpoint" || echo "Unable to fetch IP"
}

function weather {
    local loc="${1:-}"
    local url="https://wttr.in"
    [[ -n "$loc" ]] && url="$url/$loc"
    curl -m 7 -s "$url" || echo "Unable to fetch weather"
}

# Quick chmod shortcuts
function chmodx {
    chmod +x "$@"
}

# Create and enter a temporary directory
function tmp {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    cd "$tmp_dir" || return 1
    echo "Created temp directory: $tmp_dir"
}

# Load local functions if they exist
if [[ -f "$HOME/.functions.local" ]]; then
    source "$HOME/.functions.local"
fi
