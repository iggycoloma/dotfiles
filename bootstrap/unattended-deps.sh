#!/usr/bin/env bash
# Install dependency audit tools used by the post-dep-audit hook.
#
# Run as root from the unattended devcontainer's postCreateCommand.
# Tools installed:
#   - pip-audit          (pipx)
#   - cargo-audit        (cargo install; skipped if no cargo)
#   - govulncheck        (go install; skipped if no go)
#   - osv-scanner        (apt package if available, else Go install)
# npm audit ships with Node so no install needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./logging.sh
source "$SCRIPT_DIR/logging.sh"

if [[ $EUID -ne 0 ]]; then
    log_error "unattended-deps.sh must run as root (use sudo in postCreateCommand)."
    exit 1
fi

log_section "Unattended: install dep-audit tools"

apt-get update -qq

# pipx (shared) + pip-audit
if ! command -v pipx &>/dev/null; then
    apt-get install -qq -y --no-install-recommends pipx python3-venv
fi
if ! command -v pip-audit &>/dev/null; then
    log_info "Installing pip-audit via pipx..."
    PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install --pip-args='--quiet' pip-audit
fi

# cargo-audit (only if cargo is present; unattended image may skip Rust)
if command -v cargo &>/dev/null && ! command -v cargo-audit &>/dev/null; then
    log_info "Installing cargo-audit..."
    cargo install --quiet --locked cargo-audit || log_warn "cargo-audit install failed; continuing."
fi

# govulncheck (only if go is present)
if command -v go &>/dev/null && ! command -v govulncheck &>/dev/null; then
    log_info "Installing govulncheck..."
    GOBIN=/usr/local/bin go install golang.org/x/vuln/cmd/govulncheck@latest \
        || log_warn "govulncheck install failed; continuing."
fi

# osv-scanner: prefer apt, fall back to upstream release
if ! command -v osv-scanner &>/dev/null; then
    if apt-cache show osv-scanner &>/dev/null; then
        apt-get install -qq -y --no-install-recommends osv-scanner
    elif command -v go &>/dev/null; then
        log_info "Installing osv-scanner via go install..."
        GOBIN=/usr/local/bin go install github.com/google/osv-scanner/cmd/osv-scanner@latest \
            || log_warn "osv-scanner install failed; continuing."
    else
        log_warn "osv-scanner not installed (no apt package and no go). Skipping."
    fi
fi

log_info "Dep-audit tool installation complete."
