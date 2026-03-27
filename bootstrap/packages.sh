#!/usr/bin/env bash
# Package installation for dotfiles

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

# Helper: choose a SHA256 tool
_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        echo ""
    fi
}

# Helper: safe JSON selection using jq if available, else grep fallback
_select_asset_url() {
    local api_json="$1"; shift
    local pattern="$1"; shift
    if command -v jq >/dev/null 2>&1; then
        echo "$api_json" | jq -r --arg re "$pattern" '.assets[].browser_download_url | select(test($re))' | head -n1
    else
        echo "$api_json" | grep -Eo '"browser_download_url"\s*:\s*"[^"]+"' | cut -d '"' -f4 | grep -E "$pattern" | head -n1
    fi
}

_select_checksum_url() {
    local api_json="$1"
    if command -v jq >/dev/null 2>&1; then
        echo "$api_json" | jq -r '.assets[].browser_download_url' | grep -Ei '(sha256|checksums)' | head -n1
    else
        echo "$api_json" | grep -Eo '"browser_download_url"\s*:\s*"[^"]+"' | cut -d '"' -f4 | grep -Ei '(sha256|checksums)' | head -n1
    fi
}

# Helper: verify checksum if checksums file is available
# Returns: 0=verified, 1=mismatch (ABORT), 2=unavailable (WARN)
_verify_checksum() {
    local file="$1"
    local checksums_file="$2"
    local base
    base=$(basename "$file")
    if [[ -s "$checksums_file" ]]; then
        local expected
        # Use -F for literal match and handle common checksum formats
        expected=$(awk -v file="$base" '$2 == file || $2 == "./"file || $2 == "*"file {print $1; exit}' "$checksums_file")
        if [[ -n "$expected" ]]; then
            local actual
            actual=$(_sha256 "$file")
            if [[ -n "$actual" && "$actual" == "$expected" ]]; then
                return 0  # Verified successfully
            else
                log_error "Checksum mismatch for ${base}!"
                log_error "  Expected: $expected"
                log_error "  Got:      ${actual:-unknown}"
                return 1  # Mismatch - should abort
            fi
        fi
    fi
    # Checksum unavailable
    return 2
}

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

# Set -u for error on undefined variables
set -u

# Get GitHub repo for a tool (bash 3.2 compatible - no associative arrays)
get_github_repo() {
    case "$1" in
        eza) echo "eza-community/eza" ;;
        zoxide) echo "ajeetdsouza/zoxide" ;;
        starship) echo "starship/starship" ;;
        delta) echo "dandavison/delta" ;;
        lazygit) echo "jesseduffield/lazygit" ;;
        bottom) echo "ClementTsang/bottom" ;;
        atuin) echo "atuinsh/atuin" ;;
        duf) echo "muesli/duf" ;;
        procs) echo "dalance/procs" ;;
        dust) echo "bootandy/dust" ;;
        sd) echo "chmln/sd" ;;
        *) echo "" ;;
    esac
}

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

    # Attempt to install lazygit via apt/ppa on Debian/Ubuntu hosts (best-effort)
    if [[ "$minimal" != "true" ]] && ! has_tool lazygit; then
        local distro_id="" distro_like="" codename=""
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            distro_id="${ID:-}"
            distro_like="${ID_LIKE:-}"
            codename="${VERSION_CODENAME:-}"
        fi
        # First try stock apt (Ubuntu universe / Debian bookworm+) with timeout
        local apt_err
        apt_err=$(timeout 30 $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y lazygit 2>&1) && {
            log_success "Installed lazygit via apt"
        } || {
            if [[ "$distro_id" == "ubuntu" || "$distro_id" == "pop" ]]; then
                # Then try PPA on Ubuntu/derivatives (only if codename is supported)
                log_info "Attempting to install lazygit via Ubuntu PPA..."
                local ppa_release_url="https://ppa.launchpadcontent.net/lazygit-team/release/ubuntu/dists/${codename}/Release"
                if curl -fsSLI "$ppa_release_url" >/dev/null 2>&1; then
                    timeout 30 $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common >/dev/null 2>&1 || log_info "software-properties-common already installed or unavailable"
                    if command -v add-apt-repository >/dev/null 2>&1; then
                        # Use timeout and noninteractive mode to prevent hanging
                        if timeout 30 $SUDO DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:lazygit-team/release >/dev/null 2>&1; then
                            log_info "Added lazygit PPA"
                            timeout 30 $SUDO DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>&1 | grep -E "(Err|W:)" || true
                            if timeout 30 $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y lazygit >/dev/null 2>&1; then
                                log_success "Installed lazygit via apt/ppa"
                            else
                                log_warn "lazygit not available via apt/ppa (install failed)"
                            fi
                        else
                            log_warn "Failed to add lazygit PPA (timeout or error)"
                        fi
                    else
                        log_warn "add-apt-repository not available; skipping PPA addition"
                    fi
                else
                    log_warn "lazygit PPA does not provide packages for '${codename}'"
                fi
            else
                log_warn "lazygit not available via apt on this distro"
            fi
        }
    fi
}

# Install via apk (Alpine)
install_apk() {
    local minimal=$1
    local SUDO
    SUDO=$(get_sudo)

    log_info "Updating apk repositories..."
    $SUDO apk update

    log_info "Installing core tools..."
    local packages=("curl" "wget" "git" "bash" "build-base")

    # Add core tools - check availability in Alpine repos
    # Note: Some tools may have different names or not be available
    packages+=("fzf" "ripgrep" "fd" "bat" "jq")

    # Add host-specific tools
    if [[ "$minimal" != "true" ]]; then
        packages+=("tmux" "htop" "ncdu" "lazygit")
    fi

    # Install packages (some may not exist, so don't fail)
    log_info "Installing: ${packages[*]}"
    for pkg in "${packages[@]}"; do
        if $SUDO apk add "$pkg" 2>/dev/null; then
            log_info "✓ Installed $pkg"
        else
            log_warn "Package $pkg not available via apk, will try GitHub"
        fi
    done

    log_success "APK packages installation complete"
}

# Install via Homebrew (macOS)
install_brew() {
    local minimal=$1

    log_info "Installing core tools..."
    local packages=("fzf" "ripgrep" "fd" "bat" "jq" "git" "eza" "zoxide" "starship" "git-delta" "atuin")

    if [[ "$minimal" != "true" ]]; then
        packages+=("tmux" "htop" "ncdu" "direnv" "coreutils" "gnu-sed" "lazygit" "bottom")
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

    log_info "Installing $tool from GitHub (with checksum when available)..."

    local arch
    case "$(uname -m)" in
        x86_64) arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) log_error "Unsupported architecture"; return 1 ;;
    esac

    local os
    case "$(uname -s)" in
        Linux)
            # Always prefer musl on Linux — statically linked, no GLIBC version dependency.
            # GNU builds from GitHub Actions now target GLIBC 2.39+ which is newer than
            # Debian stable (Bookworm = 2.36), causing runtime failures.
            os="unknown-linux-musl"
            ;;
        Darwin) os="apple-darwin" ;;
        *) log_error "Unsupported OS"; return 1 ;;
    esac

    # Get latest release metadata
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    local api_json
    api_json=$(curl -fsSL "$api_url" 2>/dev/null || true)
    if [[ -z "$api_json" ]]; then
        log_error "Failed to query GitHub API for $repo"
        return 1
    fi
    local download_url

    case "$tool" in
        starship)
            # Install starship via release tarball (avoid curl|sh)
            local pattern
            pattern="starship.*${arch}-${os}.*\\.tar\\.gz$"
            download_url=$(_select_asset_url "$api_json" "$pattern")
            if [[ -n "$download_url" ]]; then
                log_info "Downloading: $download_url"
                local tmp_dir
                tmp_dir=$(mktemp -d)
                local tarball="$tmp_dir/asset.tar.gz"
                curl -fsSL "$download_url" -o "$tarball" || { [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"; log_error "Failed to download starship"; return 1; }
                # Attempt checksum verification when available
                local sums_url sums_file
                sums_url=$(_select_checksum_url "$api_json")
                if [[ -n "$sums_url" ]]; then
                    sums_file="$tmp_dir/checksums.txt"
                    curl -fsSL "$sums_url" -o "$sums_file" || true
                    _verify_checksum "$tarball" "$sums_file"
                    case $? in
                        0) log_success "Checksum verified for starship" ;;
                        1) log_error "Aborting starship install due to checksum mismatch"; [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"; return 1 ;;
                        2) log_warn "Checksum unavailable for starship (proceeding with caution)" ;;
                    esac
                else
                    log_warn "No checksum asset found for starship"
                fi
                if tar xzf "$tarball" -C "$tmp_dir" 2>/dev/null && find "$tmp_dir" -name starship -type f -exec cp {} "$install_dir/" \;; then
                    chmod +x "$install_dir/starship"
                    [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                else
                    log_error "Failed to extract/install starship"
                    [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                    return 1
                fi
            else
                log_error "Could not find starship release for ${arch}-${os}"
                return 1
            fi
            ;;
        eza)
            # eza releases: eza_x86_64-unknown-linux-musl.tar.gz or eza_x86_64-unknown-linux-gnu.tar.gz
            download_url=$(_select_asset_url "$api_json" "eza_${arch}-${os}.*\\.tar\\.gz$")
            if [[ -n "$download_url" ]]; then
                log_info "Downloading: $download_url"
                local tmp_dir=$(mktemp -d)
                local tarball="$tmp_dir/asset.tar.gz"
                curl -fsSL "$download_url" -o "$tarball" || { [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"; log_error "Failed to download eza"; return 1; }
                # Verify checksum when available
                local sums_url sums_file
                sums_url=$(_select_checksum_url "$api_json")
                if [[ -n "$sums_url" ]]; then
                    sums_file="$tmp_dir/checksums.txt"
                    curl -fsSL "$sums_url" -o "$sums_file" || true
                    _verify_checksum "$tarball" "$sums_file"
                    case $? in
                        0) log_success "Checksum verified for eza" ;;
                        1) log_error "Aborting eza install due to checksum mismatch"; [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"; return 1 ;;
                        2) log_warn "Checksum unavailable for eza (proceeding with caution)" ;;
                    esac
                fi
                if tar xzf "$tarball" -C "$tmp_dir"; then
                    if find "$tmp_dir" -name eza -type f -exec cp {} "$install_dir/" \;; then
                        chmod +x "$install_dir/eza"
                        [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                    else
                        log_error "Could not find eza binary in tarball"
                        [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                        return 1
                    fi
                else
                    log_error "Failed to extract eza"
                    [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                    return 1
                fi
            else
                log_error "Could not find eza release for ${arch}-${os}"
                return 1
            fi
            ;;
        zoxide)
            download_url=$(_select_asset_url "$api_json" "${arch}-${os}.*\\.tar\\.gz$")
            if [[ -n "$download_url" ]]; then
                log_info "Downloading: $download_url"
                local tmp_dir=$(mktemp -d)
                local tarball="$tmp_dir/asset.tar.gz"
                curl -fsSL "$download_url" -o "$tarball" || { [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"; log_error "Failed to download zoxide"; return 1; }
                local sums_url sums_file
                sums_url=$(_select_checksum_url "$api_json")
                if [[ -n "$sums_url" ]]; then
                    sums_file="$tmp_dir/checksums.txt"
                    curl -fsSL "$sums_url" -o "$sums_file" || true
                    _verify_checksum "$tarball" "$sums_file"
                    case $? in
                        0) log_success "Checksum verified for zoxide" ;;
                        1) log_error "Aborting zoxide install due to checksum mismatch"; [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"; return 1 ;;
                        2) log_warn "Checksum unavailable for zoxide (proceeding with caution)" ;;
                    esac
                fi
                if tar xzf "$tarball" -C "$tmp_dir"; then
                    if find "$tmp_dir" -name zoxide -type f -maxdepth 3 -exec cp {} "$install_dir/" \;; then
                        chmod +x "$install_dir/zoxide"
                        [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                    else
                        log_error "Could not find zoxide binary in tarball"
                        [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                        return 1
                    fi
                else
                    log_error "Failed to extract zoxide"
                    [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                    return 1
                fi
            else
                log_error "Could not find zoxide release for ${arch}-${os}"
                return 1
            fi
            ;;
        delta)
            # delta releases: delta-*-x86_64-unknown-linux-musl.tar.gz or delta-*-x86_64-unknown-linux-gnu.tar.gz
            download_url=$(_select_asset_url "$api_json" "${arch}-${os}.*\\.tar\\.gz$")
            if [[ -n "$download_url" ]]; then
                log_info "Downloading: $download_url"
                local tmp_dir=$(mktemp -d)
                local tarball="$tmp_dir/asset.tar.gz"
                curl -fsSL "$download_url" -o "$tarball" || { [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"; log_error "Failed to download delta"; return 1; }
                local sums_url sums_file
                sums_url=$(_select_checksum_url "$api_json")
                if [[ -n "$sums_url" ]]; then
                    sums_file="$tmp_dir/checksums.txt"
                    curl -fsSL "$sums_url" -o "$sums_file" || true
                    _verify_checksum "$tarball" "$sums_file"
                    case $? in
                        0) log_success "Checksum verified for delta" ;;
                        1) log_error "Aborting delta install due to checksum mismatch"; [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"; return 1 ;;
                        2) log_warn "Checksum unavailable for delta (proceeding with caution)" ;;
                    esac
                fi
                if tar xzf "$tarball" -C "$tmp_dir"; then
                    if find "$tmp_dir" -name delta -type f -exec cp {} "$install_dir/" \;; then
                        chmod +x "$install_dir/delta"
                        [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                    else
                        log_error "Could not find delta binary in tarball"
                        [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                        return 1
                    fi
                else
                    log_error "Failed to extract delta"
                    [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                    return 1
                fi
            else
                log_error "Could not find delta release for ${arch}-${os}"
                return 1
            fi
            ;;
        lazygit)
            # lazygit doesn't have musl binaries, only glibc (skip on pure musl systems)
            if [[ "$os" == "unknown-linux-musl" ]]; then
                log_warn "lazygit not available for musl systems, skipping"
                return 0
            fi
            # Map architecture naming to lazygit's convention (arm64 instead of aarch64)
            local lazy_arch="$arch"
            if [[ "$arch" == "aarch64" ]]; then
                lazy_arch="arm64"
            fi
            download_url=$(_select_asset_url "$api_json" "Linux_${lazy_arch}.*\\.tar\\.gz$")
            # Fallback: derive latest tag via HTTP redirect if API is restricted
            if [[ -z "$download_url" ]]; then
                local latest_url tag
                latest_url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest" 2>/dev/null || true)
                tag="${latest_url##*/}"
                if [[ -n "$tag" ]]; then
                    download_url="https://github.com/$repo/releases/download/${tag}/lazygit_${tag#v}_Linux_${lazy_arch}.tar.gz"
                fi
            fi
            if [[ -n "$download_url" ]]; then
                log_info "Downloading: $download_url"
                local tmp_dir=$(mktemp -d)
                local tarball="$tmp_dir/asset.tar.gz"
                curl -fsSL "$download_url" -o "$tarball" || { [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"; log_error "Failed to download lazygit"; return 1; }
                local sums_url sums_file
                sums_url=$(_select_checksum_url "$api_json")
                # Fallback checksums URL if API path was unavailable
                if [[ -z "$sums_url" && -n "${tag:-}" ]]; then
                    sums_url="https://github.com/$repo/releases/download/${tag}/checksums.txt"
                fi
                if [[ -n "$sums_url" ]]; then
                    sums_file="$tmp_dir/checksums.txt"
                    curl -fsSL "$sums_url" -o "$sums_file" || true
                    _verify_checksum "$tarball" "$sums_file"
                    case $? in
                        0) log_success "Checksum verified for lazygit" ;;
                        1) log_error "Aborting lazygit install due to checksum mismatch"; [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"; return 1 ;;
                        2) log_warn "Checksum unavailable for lazygit (proceeding with caution)" ;;
                    esac
                fi
                if tar xzf "$tarball" -C "$tmp_dir"; then
                    if find "$tmp_dir" -name lazygit -type f -exec cp {} "$install_dir/" \;; then
                        chmod +x "$install_dir/lazygit"
                        [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                    else
                        log_error "Could not find lazygit binary in tarball"
                        [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                        return 1
                    fi
                else
                    log_error "Failed to extract lazygit"
                    [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                    return 1
                fi
            else
                log_error "Could not find lazygit release for Linux_${arch}"
                return 1
            fi
            ;;
        atuin)
            download_url=$(_select_asset_url "$api_json" "atuin-${arch}-${os}.*\\.tar\\.gz$")
            if [[ -n "$download_url" ]]; then
                log_info "Downloading: $download_url"
                local tmp_dir=$(mktemp -d)
                local tarball="$tmp_dir/asset.tar.gz"
                curl -fsSL "$download_url" -o "$tarball" || { [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"; log_error "Failed to download atuin"; return 1; }
                local sums_url sums_file
                sums_url=$(_select_checksum_url "$api_json")
                if [[ -n "$sums_url" ]]; then
                    sums_file="$tmp_dir/checksums.txt"
                    curl -fsSL "$sums_url" -o "$sums_file" || true
                    _verify_checksum "$tarball" "$sums_file"
                    case $? in
                        0) log_success "Checksum verified for atuin" ;;
                        1) log_error "Aborting atuin install due to checksum mismatch"; [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"; return 1 ;;
                        2) log_warn "Checksum unavailable for atuin (proceeding with caution)" ;;
                    esac
                fi
                if tar xzf "$tarball" -C "$tmp_dir"; then
                    if find "$tmp_dir" -name atuin -type f -exec cp {} "$install_dir/" \;; then
                        chmod +x "$install_dir/atuin"
                        [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                    else
                        log_error "Could not find atuin binary in tarball"
                        [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                        return 1
                    fi
                else
                    log_error "Failed to extract atuin"
                    [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
                    return 1
                fi
            else
                log_error "Could not find atuin release for ${arch}-${os}"
                return 1
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

# Install only system-level prerequisites needed for Nix and basic operation
install_system_basics() {
    local pkg_mgr
    pkg_mgr=$(detect_package_manager)
    local SUDO
    SUDO=$(get_sudo)

    case "$pkg_mgr" in
        apt)
            log_info "Installing system prerequisites via apt..."
            $SUDO apt-get update -qq
            $SUDO apt-get install -y curl wget git ca-certificates xz-utils build-essential
            ;;
        apk)
            log_info "Installing system prerequisites via apk..."
            $SUDO apk update
            $SUDO apk add curl wget git bash ca-certificates xz build-base
            ;;
        brew)
            # Homebrew handles its own dependencies
            ;;
    esac
}

# Install bash-preexec (required for atuin history capture on bash)
install_bash_preexec() {
    if [[ -f "$HOME/.bash-preexec.sh" ]]; then
        log_info "bash-preexec already installed, skipping"
        return 0
    fi

    local preexec_ver="0.6.0"
    local preexec_sha="998f4d5e9dd82e254463228cc6caa4d40125ae79b31d5a16a2a2f49357f0c160"
    log_info "Installing bash-preexec v${preexec_ver} (atuin dependency for bash)..."
    if curl -fsSL "https://raw.githubusercontent.com/rcaloras/bash-preexec/${preexec_ver}/bash-preexec.sh" -o "$HOME/.bash-preexec.sh"; then
        local actual_sha
        actual_sha=$(_sha256 "$HOME/.bash-preexec.sh")
        if [[ -n "$actual_sha" && "$actual_sha" == "$preexec_sha" ]]; then
            log_success "bash-preexec installed (checksum verified)"
        else
            log_error "bash-preexec checksum mismatch! Removing downloaded file."
            rm -f "$HOME/.bash-preexec.sh"
        fi
    else
        log_warn "Failed to download bash-preexec (atuin history may not work in bash)"
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

    # 1. Install system-level prerequisites (curl, git, ca-certificates, xz)
    install_system_basics

    # Ensure ~/.local/bin is in PATH for current session
    export PATH="$HOME/.local/bin:$PATH"

    # 2. Try Nix as primary package installer (Linux only — macOS uses Homebrew)
    if [[ "$os" != "macos" ]]; then
        source "$DOTFILES_DIR/bootstrap/nix.sh"
        if install_nix; then
            install_nix_packages "$minimal"
            install_bash_preexec
            log_success "Package installation complete (via Nix)!"
            return 0
        fi
        log_warn "Nix unavailable, falling back to native package managers"
    fi

    case "$pkg_mgr" in
        apt)
            install_apt "$minimal"
            ;;
        apk)
            install_apk "$minimal"
            ;;
        brew)
            install_brew "$minimal"
            ;;
        *)
            log_warn "No supported package manager found, will try GitHub releases"
            ;;
    esac

    # Install additional tools from GitHub (skip if using Homebrew)
    if [[ "$pkg_mgr" != "brew" ]]; then
        log_info "Installing tools from GitHub releases..."

        install_from_github "starship" "$(get_github_repo starship)"
        install_from_github "eza" "$(get_github_repo eza)"
        install_from_github "zoxide" "$(get_github_repo zoxide)"
        install_from_github "delta" "$(get_github_repo delta)"
        install_from_github "atuin" "$(get_github_repo atuin)"

        install_bash_preexec

        # Host-only GitHub tools
        if [[ "$minimal" != "true" ]]; then
            install_from_github "lazygit" "$(get_github_repo lazygit)"
            install_from_github "bottom" "$(get_github_repo bottom)"
        fi
    fi

    log_success "Package installation complete!"
}

# If run directly, execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_packages
fi
