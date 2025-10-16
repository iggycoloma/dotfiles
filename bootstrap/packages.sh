#!/usr/bin/env bash
# Package installation for dotfiles

# Don't use set -e as we want to handle errors explicitly
set -u  # Error on undefined variables

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
source "$DOTFILES_DIR/bootstrap/detect.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}==>${NC} $1"; }
log_success() { echo -e "${GREEN}==>${NC} $1"; }
log_warn() { echo -e "${YELLOW}==>${NC} $1"; }
log_error() { echo -e "${RED}==>${NC} $1"; }

# Core tools needed in all environments
CORE_TOOLS=(
    fzf
    ripgrep
    fd-find
    bat
    jq
)

# Additional tools for host machines
HOST_TOOLS=(
    tmux
    htop
    ncdu
)

# Tools installed via GitHub releases (for speed)
declare -A GITHUB_RELEASES=(
    ["eza"]="eza-community/eza"
    ["zoxide"]="ajeetdsouza/zoxide"
    ["starship"]="starship/starship"
    ["delta"]="dandavison/delta"
    ["lazygit"]="jesseduffield/lazygit"
    ["bottom"]="ClementTsang/bottom"
    ["duf"]="muesli/duf"
    ["procs"]="dalance/procs"
    ["dust"]="bootandy/dust"
    ["sd"]="chmln/sd"
)

# Install via apt (Debian/Ubuntu)
install_apt() {
    local minimal=$1
    local SUDO
    SUDO=$(get_sudo)

    log_info "Updating apt repositories..."
    $SUDO apt-get update -qq

    log_info "Installing core tools..."
    local packages=("curl" "wget" "git" "build-essential")

    # Add core tools
    packages+=("ripgrep" "fd-find" "bat" "jq")

    # fzf is available in Ubuntu 20.04+
    if ! has_tool fzf; then
        packages+=("fzf")
    fi

    # Add host-specific tools
    if [[ "$minimal" != "true" ]]; then
        packages+=("tmux" "htop" "ncdu" "direnv")
    fi

    # Install packages
    log_info "Installing: ${packages[*]}"
    if $SUDO apt-get install -y "${packages[@]}"; then
        log_success "APT packages installed successfully"
    else
        log_error "Some APT packages failed to install"
        return 1
    fi

    # Create bat symlink if needed (Ubuntu calls it batcat)
    if has_tool batcat && ! has_tool bat; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(which batcat)" "$HOME/.local/bin/bat"
    fi

    # Create fd symlink if needed (Ubuntu calls it fdfind)
    if has_tool fdfind && ! has_tool fd; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
    fi
}

# Install via Homebrew (macOS)
install_brew() {
    local minimal=$1

    log_info "Installing core tools..."
    local packages=("fzf" "ripgrep" "fd" "bat" "jq" "git")

    if [[ "$minimal" != "true" ]]; then
        packages+=("tmux" "htop" "ncdu" "direnv" "coreutils" "gnu-sed")
    fi

    brew install "${packages[@]}"
    log_success "Homebrew packages installed"
}

# Install tool from GitHub releases
install_from_github() {
    local tool=$1
    local repo=$2
    local install_dir="$HOME/.local/bin"

    mkdir -p "$install_dir"

    # Skip if already installed
    if has_tool "$tool"; then
        log_info "$tool already installed, skipping"
        return 0
    fi

    log_info "Installing $tool from GitHub..."

    local arch
    case "$(uname -m)" in
        x86_64) arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) log_error "Unsupported architecture"; return 1 ;;
    esac

    local os
    case "$(uname -s)" in
        Linux) os="unknown-linux-gnu" ;;
        Darwin) os="apple-darwin" ;;
        *) log_error "Unsupported OS"; return 1 ;;
    esac

    # Get latest release URL (simplified - could be improved)
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    local download_url

    case "$tool" in
        starship)
            # Starship has an install script
            curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$install_dir"
            ;;
        eza)
            download_url=$(curl -s "$api_url" | grep "browser_download_url.*${arch}.*${os}.*\.tar\.gz" | cut -d '"' -f 4 | head -n 1)
            if [[ -n "$download_url" ]]; then
                curl -fsSL "$download_url" | tar xz -C "$install_dir" eza
            fi
            ;;
        zoxide)
            download_url=$(curl -s "$api_url" | grep "browser_download_url.*${arch}.*linux.*musl.*\.tar\.gz" | cut -d '"' -f 4 | head -n 1)
            if [[ -n "$download_url" ]]; then
                curl -fsSL "$download_url" | tar xz -C "$install_dir" zoxide
            fi
            ;;
        delta)
            download_url=$(curl -s "$api_url" | grep "browser_download_url.*${arch}.*linux.*musl.*\.tar\.gz" | cut -d '"' -f 4 | head -n 1)
            if [[ -n "$download_url" ]]; then
                local tmp_dir=$(mktemp -d)
                curl -fsSL "$download_url" | tar xz -C "$tmp_dir"
                find "$tmp_dir" -name delta -type f -executable -exec cp {} "$install_dir/" \;
                rm -rf "$tmp_dir"
            fi
            ;;
        lazygit)
            download_url=$(curl -s "$api_url" | grep "browser_download_url.*Linux_${arch}.*\.tar\.gz" | cut -d '"' -f 4 | head -n 1)
            if [[ -n "$download_url" ]]; then
                curl -fsSL "$download_url" | tar xz -C "$install_dir" lazygit
            fi
            ;;
        *)
            log_warn "No installer for $tool, skipping"
            return 1
            ;;
    esac

    if has_tool "$tool"; then
        log_success "$tool installed"
    else
        log_warn "$tool installation may have failed"
    fi
}

# Main installation function
install_packages() {
    local env os pkg_mgr minimal
    env=$(detect_environment)
    os=$(detect_os)
    pkg_mgr=$(detect_package_manager)
    minimal=$(is_minimal_install && echo "true" || echo "false")

    log_info "Environment: $env | OS: $os | Minimal: $minimal"

    # Install base packages via package manager
    case "$pkg_mgr" in
        apt)
            install_apt "$minimal"
            ;;
        brew)
            install_brew "$minimal"
            ;;
        *)
            log_warn "No supported package manager found, will try GitHub releases"
            ;;
    esac

    # Install additional tools from GitHub
    log_info "Installing tools from GitHub releases..."

    # Always install these from GitHub for latest versions
    install_from_github "starship" "${GITHUB_RELEASES[starship]}"
    install_from_github "eza" "${GITHUB_RELEASES[eza]}"
    install_from_github "zoxide" "${GITHUB_RELEASES[zoxide]}"
    install_from_github "delta" "${GITHUB_RELEASES[delta]}"

    # Host-only GitHub tools
    if [[ "$minimal" != "true" ]]; then
        install_from_github "lazygit" "${GITHUB_RELEASES[lazygit]}"
        install_from_github "bottom" "${GITHUB_RELEASES[bottom]}"
    fi

    # Ensure ~/.local/bin is in PATH for current session
    export PATH="$HOME/.local/bin:$PATH"

    log_success "Package installation complete!"
}

# If run directly, execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_packages
fi
