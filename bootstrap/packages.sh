#!/usr/bin/env bash
# Package installation for dotfiles

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/bootstrap/detect.sh"

# Shared logging functions
source "$DOTFILES_DIR/bootstrap/logging.sh"

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
        # Handle common checksum formats: "hash  filename" and "filename  hash ..." (yq-style)
        expected=$(awk -v file="$base" '
            $2 == file || $2 == "./"file || $2 == "*"file {print $1; exit}
            $1 == file {print $2; exit}
        ' "$checksums_file")
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

# Tool configuration table for GitHub release downloads.
# Sets _tc_* variables describing how to download and install each tool.
# Returns 1 for unknown tools.
_tool_config() {
    local tool="$1"
    # Defaults (most tools are tar.gz with standard checksums)
    _tc_pattern=""
    _tc_format="tar.gz"           # tar.gz | tar.xz | zip | binary
    _tc_checksum="standard"       # standard | bsd | sha256sums | none
    _tc_arch_remap=""             # "" | "arm64" | "amd64" (remap aarch64)
    _tc_x86_remap=""              # "" | "x64" | "amd64" (remap x86_64)
    _tc_os_override=""            # "" | literal os | "musl_fallback_gnu"
    _tc_skip_musl=""              # "true" to skip on musl systems
    _tc_find_depth=""             # "" | "-maxdepth N"
    _tc_binary_name="$tool"       # binary name in archive
    _tc_api_fallback=""           # "lazygit" for special HTTP redirect fallback
    _tc_binary_rename=""          # glob pattern to find + rename binary (e.g. "codex-*" -> "$tool")

    case "$tool" in
        starship)
            _tc_pattern='starship.*ARCH-OS.*\.tar\.gz$'
            ;;
        eza)
            _tc_pattern='eza_ARCH-OS.*\.tar\.gz$'
            ;;
        zoxide)
            _tc_pattern='ARCH-OS.*\.tar\.gz$'
            _tc_find_depth="-maxdepth 3"
            ;;
        delta)
            _tc_pattern='ARCH-OS.*\.tar\.gz$'
            ;;
        lazygit)
            _tc_skip_musl="true"
            _tc_arch_remap="arm64"
            _tc_pattern='Linux_ARCH.*\.tar\.gz$'
            _tc_api_fallback="lazygit"
            ;;
        atuin)
            _tc_pattern='atuin-ARCH-OS.*\.tar\.gz$'
            ;;
        sd)
            _tc_pattern='sd-v[0-9.]+-ARCH-OS\.tar\.gz$'
            _tc_checksum="none"
            ;;
        sg)
            _tc_format="zip"
            _tc_checksum="none"
            _tc_os_override="unknown-linux-gnu"
            _tc_pattern='app-ARCH-OS\.zip$'
            ;;
        difft)
            _tc_checksum="none"
            _tc_os_override="musl_fallback_gnu"
            _tc_pattern='difft-ARCH-OS\.tar\.gz$'
            ;;
        scc)
            _tc_arch_remap="arm64"
            _tc_pattern='scc_Linux_ARCH\.tar\.gz$'
            ;;
        yq)
            _tc_format="binary"
            _tc_arch_remap="arm64"
            _tc_x86_remap="amd64"
            _tc_checksum="bsd"
            _tc_pattern='yq_linux_ARCH$'
            ;;
        watchexec)
            _tc_format="tar.xz"
            _tc_checksum="sha256sums"
            _tc_pattern='watchexec-[0-9.]+-ARCH-OS\.tar\.xz$'
            ;;
        bottom)
            _tc_pattern='bottom_ARCH-OS\.tar\.gz$'
            _tc_binary_name="btm"
            ;;
        gitleaks)
            # gitleaks uses x64/arm64 (not x86_64/aarch64)
            _tc_arch_remap="arm64"
            _tc_x86_remap="x64"
            _tc_os_override="linux"
            _tc_pattern='gitleaks_[0-9.]+_OS_ARCH\.tar\.gz$'
            ;;
        codex)
            _tc_checksum="none"
            _tc_pattern='/codex-ARCH-OS\.tar\.gz$'
            # Archive contains "codex-ARCH-OS" not "codex"; _tc_binary_rename
            # tells _install_tool to find by glob and rename to "codex"
            _tc_binary_rename="codex-*"
            ;;
        *)
            return 1
            ;;
    esac
}

# Generic tool installer driven by _tool_config.
# Handles all archive formats, checksum styles, arch remapping, and OS fallbacks.
_install_tool() {
    local tool="$1" api_json="$2" repo="$3" install_dir="$4" arch="$5" os="$6"

    _tool_config "$tool" || { log_warn "No installer config for $tool, skipping"; return 1; }

    local binary_name="$_tc_binary_name"

    # Skip musl check
    if [[ "$_tc_skip_musl" == "true" && "$os" == "unknown-linux-musl" ]]; then
        log_warn "$tool not available for musl systems, skipping"
        return 0
    fi

    # Apply arch remapping for Go-style binaries
    if [[ -n "$_tc_arch_remap" && "$arch" == "aarch64" ]]; then
        arch="$_tc_arch_remap"
    fi
    if [[ -n "$_tc_x86_remap" && "$arch" == "x86_64" ]]; then
        arch="$_tc_x86_remap"
    fi

    # Apply OS override
    local effective_os="$os"
    if [[ -n "$_tc_os_override" && "$_tc_os_override" != "musl_fallback_gnu" ]]; then
        effective_os="$_tc_os_override"
    fi

    # Resolve pattern (substitute ARCH/OS placeholders)
    local pattern
    pattern="${_tc_pattern//ARCH/$arch}"
    pattern="${pattern//OS/$effective_os}"

    # Select download URL
    local download_url
    download_url=$(_select_asset_url "$api_json" "$pattern")

    # Handle musl->gnu fallback (difft: musl for x86_64 only, gnu for aarch64)
    if [[ -z "$download_url" && "$_tc_os_override" == "musl_fallback_gnu" && "$os" == "unknown-linux-musl" ]]; then
        local gnu_pattern
        gnu_pattern="${_tc_pattern//ARCH/$arch}"
        gnu_pattern="${gnu_pattern//OS/unknown-linux-gnu}"
        download_url=$(_select_asset_url "$api_json" "$gnu_pattern")
    fi

    # Lazygit API fallback: derive latest tag via HTTP redirect
    if [[ -z "$download_url" && "$_tc_api_fallback" == "lazygit" ]]; then
        local latest_url tag
        latest_url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest" 2>/dev/null || true)
        tag="${latest_url##*/}"
        if [[ -n "$tag" ]]; then
            download_url="https://github.com/$repo/releases/download/${tag}/lazygit_${tag#v}_Linux_${arch}.tar.gz"
        fi
    fi

    if [[ -z "$download_url" ]]; then
        log_error "Could not find $tool release for ${arch}"
        return 1
    fi

    log_info "Downloading: $download_url"
    local tmp_dir
    tmp_dir=$(mktemp -d) || { log_error "Failed to create temp dir"; return 1; }

    # Download asset
    local asset_file
    case "$_tc_format" in
        binary)  asset_file="$tmp_dir/$binary_name" ;;
        zip)     asset_file="$tmp_dir/asset.zip" ;;
        *)       asset_file="$tmp_dir/$(basename "$download_url")" ;;
    esac
    curl -fsSL "$download_url" -o "$asset_file" || { rm -rf "$tmp_dir"; log_error "Failed to download $tool"; return 1; }

    # Checksum verification
    case "$_tc_checksum" in
        standard)
            local sums_url sums_file
            sums_url=$(_select_checksum_url "$api_json")
            # Fallback checksums URL for lazygit API fallback path
            if [[ -z "$sums_url" && -n "${tag:-}" ]]; then
                sums_url="https://github.com/$repo/releases/download/${tag}/checksums.txt"
            fi
            if [[ -n "$sums_url" ]]; then
                sums_file="$tmp_dir/checksums.txt"
                curl -fsSL "$sums_url" -o "$sums_file" || true
                local verify_rc=0
                _verify_checksum "$asset_file" "$sums_file" || verify_rc=$?
                case $verify_rc in
                    0) log_success "Checksum verified for $tool" ;;
                    1) log_error "Aborting $tool install due to checksum mismatch"; rm -rf "$tmp_dir"; return 1 ;;
                    2) log_warn "Checksum unavailable for $tool (proceeding with caution)" ;;
                esac
            else
                log_warn "No checksum asset found for $tool"
            fi
            ;;
        sha256sums)
            local sums_url sums_file
            sums_url=$(echo "$api_json" | jq -r '.assets[].browser_download_url' 2>/dev/null | grep -F 'SHA256SUMS' | head -n1)
            if [[ -n "$sums_url" ]]; then
                sums_file="$tmp_dir/checksums.txt"
                curl -fsSL "$sums_url" -o "$sums_file" || true
                local verify_rc=0
                _verify_checksum "$asset_file" "$sums_file" || verify_rc=$?
                case $verify_rc in
                    0) log_success "Checksum verified for $tool" ;;
                    1) log_error "Aborting $tool install due to checksum mismatch"; rm -rf "$tmp_dir"; return 1 ;;
                    2) log_warn "Checksum unavailable for $tool (proceeding with caution)" ;;
                esac
            fi
            ;;
        bsd)
            local sums_url
            sums_url=$(echo "$api_json" | jq -r '.assets[].browser_download_url' 2>/dev/null | grep -F 'checksums-bsd' | head -n1)
            if [[ -n "$sums_url" ]]; then
                local sums_file="$tmp_dir/checksums-bsd"
                curl -fsSL "$sums_url" -o "$sums_file" || true
                if [[ -s "$sums_file" ]]; then
                    local expected actual asset_basename
                    asset_basename=$(basename "$download_url")
                    expected=$(grep "SHA256 ($asset_basename)" "$sums_file" | awk '{print $NF}')
                    actual=$(_sha256 "$asset_file")
                    if [[ -n "$expected" && "$expected" == "$actual" ]]; then
                        log_success "Checksum verified for $tool"
                    elif [[ -n "$expected" ]]; then
                        log_error "Checksum mismatch for $tool (expected: $expected, got: $actual)"
                        rm -rf "$tmp_dir"; return 1
                    else
                        log_warn "SHA256 not found in checksums-bsd for $tool (proceeding with caution)"
                    fi
                fi
            fi
            ;;
        none)
            # No checksum verification
            ;;
    esac

    # Extract and install
    if [[ "$_tc_format" == "binary" ]]; then
        # Bare binary -- just copy directly
        cp "$asset_file" "$install_dir/$binary_name"
        chmod +x "$install_dir/$binary_name"
    else
        # Extract archive
        local extract_ok="false"
        case "$_tc_format" in
            tar.gz)  tar xzf "$asset_file" -C "$tmp_dir" 2>/dev/null && extract_ok="true" ;;
            tar.xz)  tar xJf "$asset_file" -C "$tmp_dir" 2>/dev/null && extract_ok="true" ;;
            zip)     unzip -qo "$asset_file" -d "$tmp_dir" 2>/dev/null && extract_ok="true" ;;
        esac
        if [[ "$extract_ok" != "true" ]]; then
            log_error "Failed to extract $tool"
            rm -rf "$tmp_dir"
            return 1
        fi

        # Find and install binary
        if [[ -n "$_tc_binary_rename" ]]; then
            # Glob-based find + rename (e.g. "codex-*" -> "codex")
            # Excludes archive files to avoid matching the downloaded asset itself
            local found_bin
            # shellcheck disable=SC2086
            found_bin=$(find "$tmp_dir" -name $_tc_binary_rename -type f \
                ! -name '*.tar.gz' ! -name '*.tar.xz' ! -name '*.zip' | head -n1)
            if [[ -n "$found_bin" ]]; then
                cp "$found_bin" "$install_dir/$binary_name"
            else
                log_error "Could not find $binary_name binary in archive"
                rm -rf "$tmp_dir"
                return 1
            fi
        else
            local find_args=("$tmp_dir" -name "$binary_name" -type f)
            # Intentional word splitting for -maxdepth N
            # shellcheck disable=SC2206
            [[ -n "$_tc_find_depth" ]] && find_args+=($_tc_find_depth)
            if ! find "${find_args[@]}" -exec cp {} "$install_dir/" \; 2>/dev/null || [[ ! -f "$install_dir/$binary_name" ]]; then
                log_error "Could not find $binary_name binary in archive"
                rm -rf "$tmp_dir"
                return 1
            fi
        fi
        chmod +x "$install_dir/$binary_name"
    fi

    rm -rf "$tmp_dir"
}

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
        sg) echo "ast-grep/ast-grep" ;;
        difft) echo "Wilfred/difftastic" ;;
        scc) echo "boyter/scc" ;;
        yq) echo "mikefarah/yq" ;;
        watchexec) echo "watchexec/watchexec" ;;
        gitleaks) echo "gitleaks/gitleaks" ;;
        codex) echo "openai/codex" ;;
        *) echo "" ;;
    esac
}

# Install via apt (Debian/Ubuntu)
install_apt() {
    local minimal=$1

    log_info "Updating apt repositories..."
    run_sudo apt-get update -qq

    log_info "Installing core tools..."
    local packages=("curl" "wget" "git" "build-essential")

    # Add core tools
    packages+=("ripgrep" "fd-find" "bat" "jq" "shellcheck")

    # fzf is available in Ubuntu 20.04+
    if ! has_tool fzf; then
        packages+=("fzf")
    fi

    # AI tool dependencies (opt-out via DOTFILES_NO_AI_TOOLS=1)
    if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]]; then
        packages+=("bubblewrap")
    fi

    # Add host-specific tools
    if [[ "$minimal" != "true" ]]; then
        packages+=("tmux" "htop" "ncdu" "direnv")
    fi

    # Install packages
    log_info "Installing: ${packages[*]}"
    if run_sudo apt-get install -y "${packages[@]}"; then
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
        local distro_id="" codename=""
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            distro_id="${ID:-}"
            codename="${VERSION_CODENAME:-}"
        fi
        # First try stock apt (Ubuntu universe / Debian bookworm+) with timeout
        if timeout 30 run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y lazygit >/dev/null 2>&1; then
            log_success "Installed lazygit via apt"
        else
            if [[ "$distro_id" == "ubuntu" || "$distro_id" == "pop" ]]; then
                # Then try PPA on Ubuntu/derivatives (only if codename is supported)
                log_info "Attempting to install lazygit via Ubuntu PPA..."
                local ppa_release_url="https://ppa.launchpadcontent.net/lazygit-team/release/ubuntu/dists/${codename}/Release"
                if curl -fsSLI "$ppa_release_url" >/dev/null 2>&1; then
                    timeout 30 run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common >/dev/null 2>&1 || log_info "software-properties-common already installed or unavailable"
                    if command -v add-apt-repository >/dev/null 2>&1; then
                        # Use timeout and noninteractive mode to prevent hanging
                        if timeout 30 run_sudo env DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:lazygit-team/release >/dev/null 2>&1; then
                            log_info "Added lazygit PPA"
                            timeout 30 run_sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>&1 | grep -E "(Err|W:)" || true
                            if timeout 30 run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y lazygit >/dev/null 2>&1; then
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
        fi
    fi
}

# Install via apk (Alpine)
install_apk() {
    local minimal=$1

    log_info "Updating apk repositories..."
    run_sudo apk update

    log_info "Installing core tools..."
    local packages=("curl" "wget" "git" "bash" "build-base")

    # Add core tools - check availability in Alpine repos
    # Note: Some tools may have different names or not be available
    packages+=("fzf" "ripgrep" "fd" "bat" "jq" "shellcheck")

    # AI tool dependencies (opt-out via DOTFILES_NO_AI_TOOLS=1)
    if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]]; then
        packages+=("bubblewrap")
    fi

    # Add host-specific tools
    if [[ "$minimal" != "true" ]]; then
        packages+=("tmux" "htop" "ncdu" "lazygit")
    fi

    # Install packages (some may not exist, so don't fail)
    log_info "Installing: ${packages[*]}"
    for pkg in "${packages[@]}"; do
        if run_sudo apk add "$pkg" 2>/dev/null; then
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
    local packages=("fzf" "ripgrep" "fd" "bat" "jq" "shellcheck" "git" "eza" "zoxide" "starship" "git-delta" "sd" "scc" "yq" "watchexec")

    # Enhanced tools (opt-out via DOTFILES_NO_ATUIN=1)
    if [[ "${DOTFILES_NO_ATUIN:-}" != "1" ]]; then
        packages+=("atuin")
    fi

    # AI-adjacent tools (opt-out via DOTFILES_NO_AI_TOOLS=1)
    if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]]; then
        packages+=("ast-grep" "difftastic")
    fi

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
    _install_tool "$tool" "$api_json" "$repo" "$install_dir" "$arch" "$os"

    if has_tool "$tool"; then
        log_success "$tool installed"
    else
        log_warn "$tool installation may have failed"
    fi
}

# Install system-level prerequisites needed for basic operation
install_system_basics() {
    local pkg_mgr
    pkg_mgr=$(detect_package_manager)

    case "$pkg_mgr" in
        apt)
            log_info "Installing system prerequisites via apt..."
            run_sudo apt-get update -qq
            run_sudo apt-get install -y curl wget git ca-certificates build-essential unzip xz-utils
            ;;
        apk)
            log_info "Installing system prerequisites via apk..."
            run_sudo apk update
            run_sudo apk add curl wget git bash ca-certificates build-base unzip xz
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

# Install Claude Code via native installer (no Node.js required).
# Downloads to a temp file first so download and execution failures are
# distinguishable. No pinnable checksum -- this is Anthropic's official
# installer and is a moving target.
install_claude_code() {
    if has_tool claude; then
        log_info "Claude Code already installed, skipping"
        return 0
    fi
    log_info "Installing Claude Code via native installer..."
    # Ensure ~/.cache is writable (Docker volumes may mount it as root-owned)
    mkdir -p "$HOME/.cache"
    if [[ ! -w "$HOME/.cache" ]] && command -v sudo >/dev/null 2>&1; then
        sudo chown -R "$(id -u):$(id -g)" "$HOME/.cache"
    fi
    local tmp_script
    tmp_script=$(mktemp) || { log_warn "Failed to create temp file for Claude installer"; return 1; }
    if curl -fsSL https://claude.ai/install.sh -o "$tmp_script"; then
        if bash "$tmp_script" 2>&1; then
            # Installer may place binary outside current PATH
            export PATH="$HOME/.claude/local/bin:$HOME/.local/bin:$PATH"
            if has_tool claude; then
                log_success "Claude Code installed"
            else
                log_warn "Claude Code installer ran but 'claude' not found in PATH"
            fi
        else
            log_warn "Failed to run Claude Code installer (non-fatal)"
        fi
    else
        log_warn "Failed to download Claude Code installer (non-fatal)"
    fi
    rm -f "$tmp_script"
}

# Main installation function
install_packages() {
    local env os pkg_mgr minimal
    env=$(detect_environment)
    os=$(detect_os)
    pkg_mgr=$(detect_package_manager)
    minimal=$(is_minimal_install && echo "true" || echo "false")

    log_info "Environment: $env | OS: $os | Minimal: $minimal"

    # Install system-level prerequisites (curl, git, ca-certificates)
    install_system_basics

    # Ensure ~/.local/bin is in PATH for current session
    export PATH="$HOME/.local/bin:$PATH"

    # Install base packages via package manager
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
        log_info "Installing core tools from GitHub releases..."

        install_from_github "starship" "$(get_github_repo starship)"
        install_from_github "eza" "$(get_github_repo eza)"
        install_from_github "zoxide" "$(get_github_repo zoxide)"
        install_from_github "delta" "$(get_github_repo delta)"
        install_from_github "sd" "$(get_github_repo sd)"
        install_from_github "scc" "$(get_github_repo scc)"
        install_from_github "yq" "$(get_github_repo yq)"
        install_from_github "watchexec" "$(get_github_repo watchexec)"
        install_from_github "gitleaks" "$(get_github_repo gitleaks)"

        # Enhanced tools (opt-out via DOTFILES_NO_ATUIN=1)
        if [[ "${DOTFILES_NO_ATUIN:-}" != "1" ]]; then
            install_bash_preexec
            install_from_github "atuin" "$(get_github_repo atuin)"
        fi

        # AI-adjacent tools (opt-out via DOTFILES_NO_AI_TOOLS=1)
        if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]]; then
            install_from_github "difft" "$(get_github_repo difft)"
            install_from_github "sg" "$(get_github_repo sg)"
        fi

        # Host-only GitHub tools
        if [[ "$minimal" != "true" ]]; then
            install_from_github "lazygit" "$(get_github_repo lazygit)"
            install_from_github "bottom" "$(get_github_repo bottom)"
        fi
    fi

    # AI coding tools -- native binary installs, devcontainer only
    # (opt-out via DOTFILES_NO_AI_TOOLS=1)
    if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]] && is_devcontainer; then
        log_info "Installing AI coding tools..."
        if [[ "$pkg_mgr" != "brew" ]]; then
            install_from_github "codex" "$(get_github_repo codex)"
        fi
        install_claude_code
    fi

    log_success "Package installation complete!"
}

# If run directly, execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_packages
fi
