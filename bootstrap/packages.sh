#!/usr/bin/env bash
# Package installation for dotfiles

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/bootstrap/detect.sh"

source "$DOTFILES_DIR/bootstrap/logging.sh"
source "$DOTFILES_DIR/bootstrap/versions.sh"

_sha256() {
    if has_tool sha256sum; then
        sha256sum "$1" | awk '{print $1}'
    elif has_tool shasum; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        echo ""
    fi
}

_select_asset_url() {
    local api_json="$1"; shift
    local pattern="$1"; shift
    if has_tool jq; then
        echo "$api_json" | jq -r --arg re "$pattern" '.assets[].browser_download_url | select(test($re))' | head -n1
    else
        echo "$api_json" | grep -Eo '"browser_download_url"\s*:\s*"[^"]+"' | cut -d '"' -f4 | grep -E "$pattern" | head -n1
    fi
}

_select_checksum_url() {
    local api_json="$1"
    if has_tool jq; then
        echo "$api_json" | jq -r '.assets[].browser_download_url' | grep -Ei '(sha256|checksums)' | head -n1
    else
        echo "$api_json" | grep -Eo '"browser_download_url"\s*:\s*"[^"]+"' | cut -d '"' -f4 | grep -Ei '(sha256|checksums)' | head -n1
    fi
}

CHECKSUM_VERIFIED=0
CHECKSUM_MISMATCH=1
CHECKSUM_UNAVAILABLE=2

_verify_checksum() {
    local file="$1"
    local checksums_file="$2"
    local base
    base=$(basename "$file")
    if [[ -s "$checksums_file" ]]; then
        local expected
        # Both "hash  filename" and yq's "filename  hash ..." are in the wild
        expected=$(awk -v file="$base" '
            $2 == file || $2 == "./"file || $2 == "*"file {print $1; exit}
            $1 == file {print $2; exit}
        ' "$checksums_file")
        if [[ -n "$expected" ]]; then
            local actual
            actual=$(_sha256 "$file")
            if [[ -n "$actual" && "$actual" == "$expected" ]]; then
                return $CHECKSUM_VERIFIED
            fi
            log_error "Checksum mismatch for ${base}!"
            log_error "  Expected: $expected"
            log_error "  Got:      ${actual:-unknown}"
            return $CHECKSUM_MISMATCH
        fi
    fi
    return $CHECKSUM_UNAVAILABLE
}

# Fails only on a genuine mismatch. A checksums file that is missing, empty, or
# does not list this asset downgrades to a warning -- several upstreams publish
# releases without one, and refusing to install those is worse than the risk.
_verify_asset() {
    local tool="$1" sums_url="$2" asset_file="$3" tmp_dir="$4"
    local sums_file="$tmp_dir/checksums.txt"
    curl -fsSL "$sums_url" -o "$sums_file" || true

    local rc=0
    _verify_checksum "$asset_file" "$sums_file" || rc=$?
    case $rc in
        "$CHECKSUM_VERIFIED")
            log_success "Checksum verified for $tool" ;;
        "$CHECKSUM_MISMATCH")
            log_error "Aborting $tool install due to checksum mismatch"; return 1 ;;
        "$CHECKSUM_UNAVAILABLE")
            log_warn "Checksum unavailable for $tool (proceeding with caution)" ;;
    esac
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
        duf)
            _tc_arch_remap="arm64"
            _tc_os_override="linux"
            _tc_pattern='duf_[0-9.]+_OS_ARCH\.tar\.gz$'
            ;;
        dust)
            _tc_checksum="none"
            _tc_pattern='dust-v[0-9.]+-ARCH-OS\.tar\.gz$'
            ;;
        procs)
            _tc_format="zip"
            _tc_checksum="none"
            _tc_os_override="linux"
            _tc_pattern='procs-v[0-9.]+-ARCH-OS\.zip$'
            ;;
        hyperfine)
            _tc_checksum="none"
            _tc_pattern='hyperfine-v[0-9.]+-ARCH-OS\.tar\.gz$'
            ;;
        yazi)
            _tc_format="zip"
            _tc_checksum="none"
            _tc_pattern='yazi-ARCH-OS\.zip$'
            ;;
        mise)
            _tc_arch_remap="arm64"
            _tc_x86_remap="x64"
            _tc_os_override="linux"
            _tc_checksum="sha256sums"
            _tc_pattern='mise-v[0-9.]+-OS-ARCH-musl\.tar\.gz$'
            ;;
        carapace)
            _tc_arch_remap="arm64"
            _tc_x86_remap="amd64"
            _tc_os_override="linux"
            _tc_pattern='carapace-bin_[0-9.]+_OS_ARCH\.tar\.gz$'
            _tc_binary_name="carapace"
            ;;
        *)
            return 1
            ;;
    esac
}

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

    case "$_tc_checksum" in
        standard)
            local sums_url
            sums_url=$(_select_checksum_url "$api_json")
            # $tag is set only on the lazygit API-fallback path above, which
            # never reaches the assets list the URL would normally come from.
            if [[ -z "$sums_url" && -n "${tag:-}" ]]; then
                sums_url="https://github.com/$repo/releases/download/${tag}/checksums.txt"
            fi
            if [[ -z "$sums_url" ]]; then
                log_warn "No checksum asset found for $tool"
            elif ! _verify_asset "$tool" "$sums_url" "$asset_file" "$tmp_dir"; then
                rm -rf "$tmp_dir"; return 1
            fi
            ;;
        sha256sums)
            local sums_url
            sums_url=$(echo "$api_json" | jq -r '.assets[].browser_download_url' 2>/dev/null | grep -F 'SHA256SUMS' | head -n1)
            if [[ -n "$sums_url" ]] && ! _verify_asset "$tool" "$sums_url" "$asset_file" "$tmp_dir"; then
                rm -rf "$tmp_dir"; return 1
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

set -u

# case, not an associative array -- macOS ships bash 3.2.
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
        hyperfine) echo "sharkdp/hyperfine" ;;
        yazi) echo "sxyazi/yazi" ;;
        mise) echo "jdx/mise" ;;
        carapace) echo "carapace-sh/carapace-bin" ;;
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

_apt_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

_apk_installed() {
    apk info -e "$1" >/dev/null 2>&1
}

# One `brew list` beats N invocations of `brew --prefix --installed`. Newline
# delimiters on both ends keep the match to whole names, not substrings.
_BREW_LIST_CACHE=""
_brew_installed() {
    if [[ -z "$_BREW_LIST_CACHE" ]]; then
        _BREW_LIST_CACHE=$'\n'"$(brew list --formula 2>/dev/null)"$'\n'
    fi
    [[ "$_BREW_LIST_CACHE" == *$'\n'"$1"$'\n'* ]]
}

# Post-install verification, where has_tool would lie: bash's command cache and
# PATH are not re-evaluated after a binary lands on disk mid-session.
_managed_install_exists() {
    local tool="$1" install_dir="${2:-$HOME/.local/bin}"
    [[ -x "$install_dir/$tool" ]]
}

# Sets MISSING_PACKAGES to the subset of "$@" that $1 reports as not installed.
# Callers skip the install step outright when it comes back empty: that keeps
# re-runs idempotent and avoids loud sudo failures on hardened containers
# (--security-opt=no-new-privileges), plus brew's implicit update on install.
# bwrap unshares the network namespace and socat bridges it to the egress proxy,
# together backing Claude Code's Linux/WSL2 host sandbox. Devcontainers are
# excluded: the container boundary is the sandbox there, and bwrap inside a
# container hits known seccomp/userns incompatibilities. See docs/sandbox.md.
_wants_sandbox_deps() {
    [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]] && ! is_devcontainer
}

MISSING_PACKAGES=()
_find_missing_packages() {
    local is_installed="$1"; shift
    MISSING_PACKAGES=()
    local pkg
    for pkg in "$@"; do
        "$is_installed" "$pkg" || MISSING_PACKAGES+=("$pkg")
    done
}

# Upgrade git via ppa:git-core/ppa when stock apt git is older than the
# tracked floor (DOTFILES_MIN_GIT in bootstrap/versions.sh -- the rationale
# for the floor lives there too). The PPA is the primary path on Ubuntu;
# other distros get a loud warning and wt degrades to absolute worktree
# pointers. Idempotent: a no-op at or above the floor.
_ensure_modern_git_apt() {
    has_tool git || return 0

    local current minimum="$DOTFILES_MIN_GIT"
    current=$(git --version 2>/dev/null | awk '{print $3}')
    [[ -n "$current" ]] || return 0
    if dpkg --compare-versions "$current" ge "$minimum"; then
        return 0
    fi

    local distro_id="" codename=""
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        distro_id="${ID:-}"
        codename="${VERSION_CODENAME:-}"
    fi
    if [[ "$distro_id" != "ubuntu" && "$distro_id" != "pop" ]]; then
        log_warn "git ${current} < ${minimum} (worktree --relative-paths needs ${minimum}, key:: signingkey needs 2.35); upgrade git manually on this distro -- wt falls back to absolute worktree pointers until then"
        return 0
    fi

    log_info "Upgrading git via ppa:git-core/ppa (stock ${current} < ${minimum})..."
    local _sudo=""
    is_root || _sudo="sudo"
    local ppa_release_url="https://ppa.launchpadcontent.net/git-core/ppa/ubuntu/dists/${codename}/Release"
    if ! curl -fsSLI "$ppa_release_url" >/dev/null 2>&1; then
        log_warn "git-core PPA does not publish for '${codename}'; leaving git at ${current}"
        return 0
    fi
    timeout 30 $_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common >/dev/null 2>&1 || true
    if ! has_tool add-apt-repository; then
        log_warn "add-apt-repository unavailable; cannot add git-core PPA"
        return 0
    fi
    if ! timeout 30 $_sudo env DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:git-core/ppa >/dev/null 2>&1; then
        log_warn "Failed to add git-core PPA"
        return 0
    fi
    timeout 30 $_sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>&1 | grep -E "(Err|W:)" || true
    if timeout 60 $_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y git >/dev/null 2>&1; then
        log_success "Upgraded git to $(git --version | awk '{print $3}')"
    else
        log_warn "git-core PPA install failed; leaving git at ${current}"
    fi
}

install_apt() {
    local minimal=$1

    log_info "Installing core tools..."
    local packages=("curl" "wget" "git" "build-essential" \
                    "ripgrep" "fd-find" "bat" "jq" "shellcheck")

    if ! has_tool fzf; then
        packages+=("fzf")
    fi

    if _wants_sandbox_deps; then
        packages+=("bubblewrap" "socat")
    fi

    if [[ "$minimal" != "true" ]]; then
        packages+=("tmux" "htop" "ncdu" "direnv")
    fi

    _find_missing_packages _apt_installed "${packages[@]}"

    if [[ ${#MISSING_PACKAGES[@]} -eq 0 ]]; then
        log_info "All core apt packages already installed, skipping update + install"
    else
        log_info "Updating apt repositories..."
        run_sudo apt-get update -qq
        log_info "Installing: ${MISSING_PACKAGES[*]}"
        if run_sudo apt-get install -y "${MISSING_PACKAGES[@]}"; then
            log_success "APT packages installed successfully"
        else
            log_error "Some APT packages failed to install"
            return 1
        fi
    fi

    _ensure_modern_git_apt

    if has_tool batcat && ! has_tool bat; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(which batcat)" "$HOME/.local/bin/bat"
    fi

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
        # Note: timeout requires a real binary, not a shell function, so we
        # use sudo directly instead of run_sudo here.
        local _sudo=""
        is_root || _sudo="sudo"
        if timeout 30 $_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y lazygit >/dev/null 2>&1; then
            log_success "Installed lazygit via apt"
        else
            if [[ "$distro_id" == "ubuntu" || "$distro_id" == "pop" ]]; then
                # Then try PPA on Ubuntu/derivatives (only if codename is supported)
                log_info "Attempting to install lazygit via Ubuntu PPA..."
                local ppa_release_url="https://ppa.launchpadcontent.net/lazygit-team/release/ubuntu/dists/${codename}/Release"
                if curl -fsSLI "$ppa_release_url" >/dev/null 2>&1; then
                    timeout 30 $_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common >/dev/null 2>&1 || log_info "software-properties-common already installed or unavailable"
                    if has_tool add-apt-repository; then
                        # Use timeout and noninteractive mode to prevent hanging
                        if timeout 30 $_sudo env DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:lazygit-team/release >/dev/null 2>&1; then
                            log_info "Added lazygit PPA"
                            timeout 30 $_sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>&1 | grep -E "(Err|W:)" || true
                            if timeout 30 $_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y lazygit >/dev/null 2>&1; then
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

    # Install carapace-bin via apt (fury.io repo)
    if ! has_tool carapace; then
        log_info "Adding carapace-bin apt repository..."
        echo "deb [trusted=yes] https://apt.fury.io/rsteube/ /" | run_sudo tee /etc/apt/sources.list.d/fury.list >/dev/null
        run_sudo apt-get update -qq
        if run_sudo apt-get install -y carapace-bin; then
            log_success "Installed carapace-bin via apt"
        else
            log_warn "carapace-bin apt install failed; will try GitHub release"
        fi
    fi
}

install_apk() {
    local minimal=$1

    log_info "Installing core tools..."
    local packages=("curl" "wget" "git" "bash" "build-base" \
                    "fzf" "ripgrep" "fd" "bat" "jq" "shellcheck")

    if _wants_sandbox_deps; then
        packages+=("bubblewrap" "socat")
    fi

    if [[ "$minimal" != "true" ]]; then
        packages+=("tmux" "htop" "ncdu" "lazygit")
    fi

    _find_missing_packages _apk_installed "${packages[@]}"

    if [[ ${#MISSING_PACKAGES[@]} -eq 0 ]]; then
        log_info "All core apk packages already installed, skipping update + install"
        return 0
    fi

    log_info "Updating apk repositories..."
    run_sudo apk update

    # One at a time: not every name exists in every Alpine release, and a
    # single missing package would fail the whole batch.
    log_info "Installing: ${MISSING_PACKAGES[*]}"
    local pkg
    for pkg in "${MISSING_PACKAGES[@]}"; do
        if run_sudo apk add "$pkg" 2>/dev/null; then
            log_info "Installed $pkg"
        else
            log_warn "Package $pkg not available via apk, will try GitHub"
        fi
    done

    log_success "APK packages installation complete"
}

install_brew() {
    local minimal=$1

    log_info "Installing core tools..."
    local packages=("fzf" "ripgrep" "fd" "bat" "jq" "shellcheck" "gitleaks" "git" "eza" "zoxide" "starship" "git-delta" "sd" "scc" "yq" "watchexec" "duf" "dust" "procs" "hyperfine" "yazi" "mise" "carapace" "flock")

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

    _find_missing_packages _brew_installed "${packages[@]}"

    if [[ ${#MISSING_PACKAGES[@]} -eq 0 ]]; then
        log_info "All core brew formulas already installed, skipping install"
    else
        log_info "Installing: ${MISSING_PACKAGES[*]}"
        brew install "${MISSING_PACKAGES[@]}"
        log_success "Homebrew packages installed"
    fi

    # Clear cache so a subsequent install_packages call in the same shell
    # session sees any formulas we just installed.
    _BREW_LIST_CACHE=""
}

install_from_github() {
    local tool=$1
    local repo=$2
    local install_dir="$HOME/.local/bin"

    mkdir -p "$install_dir"

    # Install-once. Staying current is the tool's own job: `codex update` and
    # `claude update` do it in place, without install.sh spending an
    # unauthenticated GitHub API call per run against a 60/hour limit.
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
        # An already-installed tool stays usable when the API is unreachable;
        # only a first install is a real failure.
        has_tool "$tool" && return 0
        return 1
    fi

    _install_tool "$tool" "$api_json" "$repo" "$install_dir" "$arch" "$os"

    if _managed_install_exists "$tool" "$install_dir"; then
        log_success "$tool installed"
    else
        log_warn "$tool installation may have failed"
    fi
}

install_system_basics() {
    local pkg_mgr
    pkg_mgr=$(detect_package_manager)

    case "$pkg_mgr" in
        apt)
            _find_missing_packages _apt_installed \
                curl wget git ca-certificates build-essential unzip xz-utils file
            if [[ ${#MISSING_PACKAGES[@]} -eq 0 ]]; then
                log_info "System prerequisites already installed, skipping apt"
                return 0
            fi
            log_info "Installing system prerequisites via apt (missing: ${MISSING_PACKAGES[*]})..."
            run_sudo apt-get update -qq
            run_sudo apt-get install -y "${MISSING_PACKAGES[@]}"
            ;;
        apk)
            _find_missing_packages _apk_installed \
                curl wget git bash ca-certificates build-base unzip xz file
            if [[ ${#MISSING_PACKAGES[@]} -eq 0 ]]; then
                log_info "System prerequisites already installed, skipping apk"
                return 0
            fi
            log_info "Installing system prerequisites via apk (missing: ${MISSING_PACKAGES[*]})..."
            run_sudo apk update
            run_sudo apk add "${MISSING_PACKAGES[@]}"
            ;;
        brew)
            # Homebrew handles its own dependencies
            ;;
        *)
            log_warn "Unsupported package manager -- skipping system packages"
            log_info "Ensure git, curl, and unzip are installed manually"
            log_info "GitHub release tools, shell config, and symlinks will still install"
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

# No pinnable checksum -- Anthropic's installer is a moving target.
install_claude_code() {
    # Install-once, like every other tool. `claude update` is the supported way
    # to move an existing install forward, and running it from here would also
    # risk swapping the binary under a live session.
    if has_tool claude; then
        log_info "Claude Code already installed, skipping"
        return 0
    fi
    log_info "Installing Claude Code via native installer..."
    # Docker volumes may mount ~/.cache as root-owned; the installer needs it.
    mkdir -p "$HOME/.cache"
    if [[ ! -w "$HOME/.cache" ]] && has_tool sudo; then
        sudo chown -R "$(id -u):$(id -g)" "$HOME/.cache"
    fi
    local tmp_script
    tmp_script=$(mktemp) || { log_warn "Failed to create temp file for Claude installer"; return 1; }
    if curl -fsSL https://claude.ai/install.sh -o "$tmp_script"; then
        if bash "$tmp_script" 2>&1; then
            # Installer may place binary outside current PATH
            export PATH="$HOME/.claude/local/bin:$HOME/.local/bin:$PATH"
            if _managed_install_exists claude "$HOME/.claude/local/bin" \
                || _managed_install_exists claude "$HOME/.local/bin"; then
                log_success "Claude Code installed"
            else
                log_warn "Claude Code installer ran but 'claude' not found in expected paths"
            fi
        else
            log_warn "Failed to run Claude Code installer (non-fatal)"
        fi
    else
        log_warn "Failed to download Claude Code installer (non-fatal)"
    fi
    rm -f "$tmp_script"
}

# Dev Containers CLI: launches per-worktree containers from the host
# (worktree-orchestrator's docs/agentic-worktree-dev-environment.md).
# Host-only by design --
# containers never launch containers, so inside one it is dead weight.
# Homebrew ships a formula; apt/apk have no package, so Linux hosts use
# the upstream installer, which bundles its own Node.js runtime into
# ~/.devcontainers (same vendor-script pattern as install_claude_code).
# Version floor for worktree common-dir mounting is CLI 0.81.0; the
# installer resolves latest, and `wt doctor` owns the floor check.
install_devcontainer_cli() {
    if is_devcontainer; then
        return 0
    fi
    if has_tool devcontainer; then
        log_info "Dev Containers CLI already installed, skipping"
        return 0
    fi
    if [[ "$(detect_package_manager)" == "brew" ]]; then
        log_info "Installing Dev Containers CLI via Homebrew..."
        if brew install devcontainer; then
            log_success "Dev Containers CLI installed"
        else
            log_warn "Failed to install Dev Containers CLI via Homebrew (non-fatal)"
        fi
        return 0
    fi
    log_info "Installing Dev Containers CLI via upstream installer..."
    local tmp_script
    tmp_script=$(mktemp) || { log_warn "Failed to create temp file for Dev Containers CLI installer"; return 1; }
    if curl -fsSL https://raw.githubusercontent.com/devcontainers/cli/main/scripts/install.sh -o "$tmp_script"; then
        if sh "$tmp_script" 2>&1; then
            export PATH="$HOME/.devcontainers/bin:$PATH"
            if _managed_install_exists devcontainer "$HOME/.devcontainers/bin"; then
                log_success "Dev Containers CLI installed"
            else
                log_warn "Dev Containers CLI installer ran but 'devcontainer' not found in expected path"
            fi
        else
            log_warn "Failed to run Dev Containers CLI installer (non-fatal)"
        fi
    else
        log_warn "Failed to download Dev Containers CLI installer (non-fatal)"
    fi
    rm -f "$tmp_script"
}

install_packages() {
    local env os pkg_mgr minimal
    env=$(detect_environment)
    os=$(detect_os)
    pkg_mgr=$(detect_package_manager)
    minimal=$(is_minimal_install && echo "true" || echo "false")

    log_info "Environment: $env | OS: $os | Minimal: $minimal"

    install_system_basics

    export PATH="$HOME/.local/bin:$PATH"

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
            log_warn "No supported package manager (apt/apk/brew) found"
            log_info "Skipping package-manager installs; GitHub release tools will still install"
            ;;
    esac

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
        install_from_github "duf" "$(get_github_repo duf)"
        install_from_github "dust" "$(get_github_repo dust)"
        install_from_github "procs" "$(get_github_repo procs)"
        install_from_github "hyperfine" "$(get_github_repo hyperfine)"
        install_from_github "yazi" "$(get_github_repo yazi)"
        install_from_github "carapace" "$(get_github_repo carapace)"

        if [[ "${DOTFILES_NO_ATUIN:-}" != "1" ]]; then
            install_bash_preexec
            install_from_github "atuin" "$(get_github_repo atuin)"
        fi

        if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]]; then
            install_from_github "difft" "$(get_github_repo difft)"
            install_from_github "sg" "$(get_github_repo sg)"
        fi

        if [[ "$minimal" != "true" ]]; then
            install_from_github "lazygit" "$(get_github_repo lazygit)"
            install_from_github "bottom" "$(get_github_repo bottom)"
            install_from_github "mise" "$(get_github_repo mise)"
        fi
    fi

    # Hosts included, unlike the GitHub-release block above: these are developer
    # tools, not project-dependent ones. See docs/agentic-tooling.md.
    if [[ "${DOTFILES_NO_AI_TOOLS:-}" != "1" ]]; then
        log_info "Installing AI coding tools..."
        install_from_github "codex" "$(get_github_repo codex)"
        install_claude_code
        install_devcontainer_cli
    fi

    log_success "Package installation complete!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_packages
fi
