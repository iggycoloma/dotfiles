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
    # shellcheck disable=SC2016  # single quotes intentional: fzf evaluates the preview command
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
    local note_file
    note_file="$notes_dir/$(date +%Y-%m-%d).md"

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

# Smart cat that uses bat for terminal output, plain cat for pipes
# This prevents decorations (line numbers, headers) from breaking scripts
function cat {
    if command -v bat &> /dev/null; then
        if [[ -t 1 ]]; then
            # stdout is a terminal - use bat with styling
            bat --paging=never "$@"
        else
            # stdout is not a terminal (pipe/redirect) - use plain cat
            command cat "$@"
        fi
    else
        # bat not available, use system cat
        command cat "$@"
    fi
}

# Alias for original cat without any wrappers
alias ccat='command cat'

# Verify dotfiles installation state (read-only diagnostic)
function dotfiles-doctor {
    local pass=0 fail=0 warn=0

    _doc_pass() { echo -e "\033[0;32m  ok\033[0m  $1"; ((pass++)); }
    _doc_fail() { echo -e "\033[0;31m  FAIL\033[0m $1"; ((fail++)); }
    _doc_warn() { echo -e "\033[1;33m  warn\033[0m $1"; ((warn++)); }

    _doc_check_symlink() {
        local target="$1" label="$2"
        if [[ -L "$target" ]]; then
            _doc_pass "$label -> $(readlink "$target")"
        elif [[ -e "$target" ]]; then
            _doc_warn "$label exists but is not a symlink"
        else
            _doc_fail "$label missing"
        fi
    }

    _doc_check_tool() {
        local tool="$1" label="${2:-$1}"
        if command -v "$tool" &>/dev/null; then
            local ver
            ver=$("$tool" --version 2>/dev/null | head -1 || echo "unknown")
            _doc_pass "$label ($ver)"
        else
            _doc_warn "$label not found"
        fi
    }

    echo "dotfiles doctor -- checking installation health"
    echo ""

    _doc_check_git_include() {
        local config="$HOME/.config/git/config"
        if [[ -f "$config" ]] && grep -qF "git/.gitconfig" "$config" 2>/dev/null; then
            _doc_pass "git config includes dotfiles settings"
        elif [[ -L "$config" ]]; then
            _doc_warn "git config is a symlink (legacy, run install.sh to migrate)"
        elif [[ -f "$config" ]]; then
            _doc_fail "git config exists but missing dotfiles [include]"
        else
            _doc_fail "git config (XDG) missing"
        fi
    }

    echo "== Symlinks =="
    _doc_check_symlink "$HOME/.bashrc" ".bashrc"
    _doc_check_symlink "$HOME/.zshrc" ".zshrc"
    _doc_check_git_include
    _doc_check_symlink "$HOME/.config/git/hooks" "git hooks"
    _doc_check_symlink "$HOME/.config/starship.toml" "starship config"
    _doc_check_symlink "$HOME/.gitignore_global" ".gitignore_global"
    echo ""

    echo "== Core Tools =="
    _doc_check_tool git
    _doc_check_tool curl
    _doc_check_tool fzf
    _doc_check_tool rg "ripgrep"
    _doc_check_tool fd
    _doc_check_tool bat
    _doc_check_tool jq
    _doc_check_tool duf
    _doc_check_tool dust
    _doc_check_tool procs
    _doc_check_tool hyperfine
    echo ""

    echo "== Enhanced Tools =="
    _doc_check_tool starship
    _doc_check_tool zoxide
    _doc_check_tool eza
    _doc_check_tool delta "git-delta"
    _doc_check_tool atuin
    _doc_check_tool sd
    _doc_check_tool sg "ast-grep"
    _doc_check_tool difft "difftastic"
    _doc_check_tool scc
    _doc_check_tool yq
    _doc_check_tool watchexec
    _doc_check_tool gitleaks
    _doc_check_tool shellcheck
    echo ""

    echo "== Git Configuration =="
    if git config user.name >/dev/null 2>&1; then
        _doc_pass "git user.name: $(git config user.name)"
    else
        _doc_fail "git user.name not set"
    fi
    if git config user.email >/dev/null 2>&1; then
        _doc_pass "git user.email: $(git config user.email)"
    else
        _doc_fail "git user.email not set"
    fi
    if git config core.hooksPath >/dev/null 2>&1; then
        _doc_pass "global hooks: $(git config core.hooksPath)"
    else
        _doc_fail "global hooks not configured"
    fi
    if git config user.signingkey >/dev/null 2>&1; then
        _doc_pass "commit signing configured"
    else
        _doc_warn "commit signing not configured"
    fi
    echo ""

    echo "== Summary =="
    echo -e "  \033[0;32m$pass passed\033[0m, \033[1;33m$warn warnings\033[0m, \033[0;31m$fail failed\033[0m"

    # Clean up helper functions from shell namespace
    unset -f _doc_pass _doc_fail _doc_warn _doc_check_symlink _doc_check_tool _doc_check_git_include
    [[ $fail -eq 0 ]] && return 0 || return 1
}

# Load local functions if they exist
if [[ -f "$HOME/.functions.local" ]]; then
    source "$HOME/.functions.local"
fi
