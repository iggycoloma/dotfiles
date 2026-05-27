#!/usr/bin/env bash
# Environment and OS detection for dotfiles installation

# Detect environment type
detect_environment() {
    if [[ -n "${CODESPACES:-}" ]]; then
        echo "codespaces"
    elif [[ -n "${REMOTE_CONTAINERS:-}" ]]; then
        echo "devcontainer"
    elif [[ -f /.dockerenv ]]; then
        # Plain `docker run` shells (and devcontainers built without the VS
        # Code remote helper exporting REMOTE_CONTAINERS) still set this
        # sentinel at container start.
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

# Run a command with sudo if needed (safe replacement for unquoted $SUDO)
run_sudo() {
    if is_root; then
        "$@"
    else
        sudo "$@"
    fi
}

# True inside a devcontainer or Codespaces -- the two contexts where the
# installer skips host-only steps (GUI apps, brew taps, etc).
is_devcontainer() {
    local env
    env=$(detect_environment)
    [[ "$env" == "devcontainer" ]] || [[ "$env" == "codespaces" ]]
}

# Alias kept for caller intent: gate "should we do a minimal install" rather
# than "are we in a container". Currently equivalent; if the policy ever
# diverges (e.g. minimal on CI runners too), only this body changes.
is_minimal_install() {
    is_devcontainer
}

# Check if the dotfiles repo itself is the active workspace
is_dotfiles_workspace() {
    [[ -n "${DOTFILES_WORKSPACE:-}" ]]
}

# Detect the best available state persistence tier for devcontainers.
# Pure detection -- sets STATE_TIER and STATE_PATH, no side effects.
# Tiers: volume > codespaces > ephemeral
detect_state_tier() {
    # shellcheck disable=SC2034  # STATE_TIER/STATE_PATH read by callers and tests
    STATE_TIER=""
    STATE_PATH=""

    # Tier 1: Volume mount (real directory, not a symlink from a previous tier)
    if [[ -d "$HOME/.dotfiles-state" ]] && [[ ! -L "$HOME/.dotfiles-state" ]]; then
        STATE_TIER="volume"
        STATE_PATH="$HOME/.dotfiles-state"
        return
    fi

    # Tier 2: Codespaces persistent share
    if [[ "${CODESPACES:-}" == "true" ]]; then
        STATE_TIER="codespaces"
        STATE_PATH="/workspaces/.codespaces/.persistedshare/dotfiles-state"
        return
    fi

    # Tier 3: Ephemeral (lost on rebuild)
    # shellcheck disable=SC2034  # read by callers (setup_state_persistence)
    STATE_TIER="ephemeral"
    # shellcheck disable=SC2034  # read by callers (setup_state_persistence)
    STATE_PATH="$HOME/.dotfiles-state"
}

# Export detection functions for use in other scripts
export -f detect_environment
export -f detect_os
export -f detect_package_manager
export -f is_root
export -f has_tool
export -f run_sudo
export -f is_minimal_install
export -f is_devcontainer
export -f is_dotfiles_workspace
export -f detect_state_tier

# If sourced, don't execute; if run directly, show info
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Environment: $(detect_environment)"
    echo "OS: $(detect_os)"
    echo "Package Manager: $(detect_package_manager)"
    echo "Minimal Install: $(is_minimal_install && echo "yes" || echo "no")"
    echo "Devcontainer: $(is_devcontainer && echo "yes" || echo "no")"
    echo "Root: $(is_root && echo "yes" || echo "no")"
fi
