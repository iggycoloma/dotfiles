#!/usr/bin/env bash
# Environment and OS detection for dotfiles installation

# Detect environment type
detect_environment() {
    if [[ -n "${CODESPACES:-}" ]]; then
        echo "codespaces"
    elif [[ -n "${REMOTE_CONTAINERS:-}" ]]; then
        echo "devcontainer"
    elif [[ -n "${SSH_CONNECTION:-}" ]] || [[ -n "${SSH_CLIENT:-}" ]]; then
        echo "remote"
    else
        echo "local"
    fi
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|pop) echo "debian" ;;
            alpine) echo "alpine" ;;
            fedora|rhel|centos) echo "fedora" ;;
            arch|manjaro) echo "arch" ;;
            *) echo "linux" ;;
        esac
    else
        echo "unknown"
    fi
}

# Detect available package manager
detect_package_manager() {
    if command -v brew &> /dev/null; then
        echo "brew"
    elif command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v apk &> /dev/null; then
        echo "apk"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "none"
    fi
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Check if tool is already installed
has_tool() {
    command -v "$1" &> /dev/null
}

# Get sudo prefix if needed (legacy -- prefer run_sudo)
get_sudo() {
    if is_root; then
        echo ""
    else
        echo "sudo"
    fi
}

# Run a command with sudo if needed (safe replacement for unquoted $SUDO)
run_sudo() {
    if is_root; then
        "$@"
    else
        sudo "$@"
    fi
}

# Determine if this is a minimal (container) install
is_minimal_install() {
    local env
    env=$(detect_environment)
    [[ "$env" == "codespaces" ]] || [[ "$env" == "devcontainer" ]]
}

# Check if running in a devcontainer specifically
is_devcontainer() {
    local env
    env=$(detect_environment)
    [[ "$env" == "devcontainer" ]] || [[ "$env" == "codespaces" ]]
}

# Check if the dotfiles repo itself is the active workspace
is_dotfiles_workspace() {
    [[ -n "${DOTFILES_WORKSPACE:-}" ]]
}

# Export detection functions for use in other scripts
export -f detect_environment
export -f detect_os
export -f detect_package_manager
export -f is_root
export -f has_tool
export -f get_sudo
export -f run_sudo
export -f is_minimal_install
export -f is_devcontainer
export -f is_dotfiles_workspace

# If sourced, don't execute; if run directly, show info
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Environment: $(detect_environment)"
    echo "OS: $(detect_os)"
    echo "Package Manager: $(detect_package_manager)"
    echo "Minimal Install: $(is_minimal_install && echo "yes" || echo "no")"
    echo "Devcontainer: $(is_devcontainer && echo "yes" || echo "no")"
    echo "Root: $(is_root && echo "yes" || echo "no")"
fi
