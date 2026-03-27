#!/usr/bin/env bash
# Nix package manager installation and package management
#
# Uses Nix as the primary package installer for CLI tools across all platforms.
# Falls back to native package managers if Nix installation fails.

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
source "$DOTFILES_DIR/bootstrap/detect.sh"

# Source Nix environment into current shell session
_source_nix() {
    if [[ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    elif [[ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]]; then
        . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    fi
}

# Install Nix using the NixOS nix-installer
# Works without systemd, handles root/non-root, enables nix-command + flakes
install_nix() {
    # Already installed?
    _source_nix
    if command -v nix &>/dev/null; then
        log_info "Nix already installed"
        return 0
    fi

    log_info "Installing Nix (NixOS nix-installer)..."

    local env
    env=$(detect_environment)

    # Build installer arguments
    local installer_args=(install --no-confirm)

    # Containers/CI: no init system available
    if [[ "$env" == "devcontainer" || "$env" == "codespaces" || -n "${CI:-}" ]]; then
        installer_args=(install linux --init none --no-confirm)
    fi

    if curl --proto '=https' --tlsv1.2 -sSf -L https://artifacts.nixos.org/nix-installer \
        | sh -s -- "${installer_args[@]}"; then
        # Make nix available in current session
        _source_nix
        if command -v nix &>/dev/null; then
            log_success "Nix installed successfully"
            return 0
        else
            log_error "Nix installed but not found on PATH"
            return 1
        fi
    else
        log_error "Nix installation failed"
        return 1
    fi
}

# Install CLI tools via nix profile install
install_nix_packages() {
    local minimal=${1:-false}

    if ! command -v nix &>/dev/null; then
        log_error "Nix not available"
        return 1
    fi

    # Core tools (all environments)
    local packages=(
        fzf
        ripgrep
        fd
        bat
        jq
        eza
        zoxide
        starship
        delta
        atuin
    )

    # Additional tools for host machines
    if [[ "$minimal" != "true" ]]; then
        packages+=(
            lazygit
            bottom
            tmux
            htop
            ncdu
            direnv
            duf
            procs
            dust
            sd
        )
    fi

    log_info "Installing ${#packages[@]} packages via Nix..."

    local failed=0
    for pkg in "${packages[@]}"; do
        # Map nixpkgs attribute to binary name for skip check
        local bin_name="$pkg"
        case "$pkg" in
            ripgrep)  bin_name="rg" ;;
            fd)       bin_name="fd" ;;
            delta)    bin_name="delta" ;;
            bottom)   bin_name="btm" ;;
            dust)     bin_name="dust" ;;
        esac

        # Skip only if already installed via Nix profile
        local nix_bin="$HOME/.nix-profile/bin/$bin_name"
        if [[ -x "$nix_bin" ]] || readlink -f "$(command -v "$bin_name" 2>/dev/null)" 2>/dev/null | grep -q "/nix/store"; then
            log_info "$pkg already installed via Nix, skipping"
            continue
        fi

        log_info "Installing $pkg..."
        if nix profile add "nixpkgs#$pkg"; then
            log_success "$pkg installed"
        else
            log_warn "Failed to install $pkg via Nix"
            ((failed++)) || true
        fi
    done

    if [[ $failed -gt 0 ]]; then
        log_warn "$failed package(s) failed to install via Nix"
    fi

    log_success "Nix package installation complete"
    return 0
}
