#!/usr/bin/env bash
# Configure the unattended devcontainer's egress boundary.
#
# Installs mitmproxy and configures it as a local HTTPS proxy with a
# block_list addon. All HTTPS traffic from Claude and its tools is routed
# through the proxy via HTTPS_PROXY env vars; requests to hosts not on the
# allowlist are dropped. Every request is logged to
# ~/.local/state/ralph/runs/<timestamp>/egress.mitm for post-hoc review.
#
# If NET_ADMIN is available, we also install iptables rules that DROP direct
# :80/:443 egress so libraries that ignore HTTPS_PROXY still hit the block.
# Without NET_ADMIN we log a warning and fall back to env-var-only enforcement.
#
# Must run as root (postCreateCommand should wrap with sudo).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=./logging.sh
source "$SCRIPT_DIR/logging.sh"

ALLOWLIST_FILE="${ALLOWLIST_FILE:-$DOTFILES_DIR/claude-code/unattended/egress-allowlist.txt}"
MITMPROXY_DIR="${MITMPROXY_DIR:-/etc/mitmproxy}"
PROXY_PORT="${PROXY_PORT:-8080}"
PROXY_USER="${PROXY_USER:-mitmproxy}"
PROFILE_SNIPPET="/etc/profile.d/99-unattended-proxy.sh"
SYSTEMD_UNIT="/etc/systemd/system/mitmproxy-unattended.service"
ADDON_FILE="$MITMPROXY_DIR/block_non_allowlisted.py"

if [[ $EUID -ne 0 ]]; then
    log_error "unattended-proxy.sh must run as root (use sudo in postCreateCommand)."
    exit 1
fi

if [[ ! -f "$ALLOWLIST_FILE" ]]; then
    log_error "Allowlist not found: $ALLOWLIST_FILE"
    exit 1
fi

log_section "Unattended proxy: setup"

# --- Install mitmproxy ---

if ! command -v mitmdump &>/dev/null; then
    log_info "Installing mitmproxy via pipx..."
    apt-get update -qq
    apt-get install -qq -y --no-install-recommends pipx python3-venv ca-certificates iptables
    # pipx into /usr/local so every user sees it
    PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install --pip-args='--quiet' mitmproxy
fi

# --- Dedicated user for the proxy ---

if ! id "$PROXY_USER" &>/dev/null; then
    log_info "Creating user $PROXY_USER..."
    useradd --system --home-dir "$MITMPROXY_DIR" --shell /usr/sbin/nologin "$PROXY_USER"
fi

install -d -o "$PROXY_USER" -g "$PROXY_USER" -m 750 "$MITMPROXY_DIR"

# --- Addon: reject requests not on the allowlist ---

cat > "$ADDON_FILE" <<'PYEOF'
"""
mitmproxy addon: drop HTTP(S) requests whose host is not on the allowlist.

The allowlist is read at addon load time from the path in the
UNATTENDED_ALLOWLIST env var. One host per line; comments and blank lines
ignored. Matches are exact (no wildcards). If you need a subdomain,
list it explicitly.
"""
import os
import pathlib

from mitmproxy import http


class BlockNonAllowlisted:
    def __init__(self):
        path = os.environ.get("UNATTENDED_ALLOWLIST")
        if not path:
            raise RuntimeError("UNATTENDED_ALLOWLIST env var is required")
        self.allowed = self._load(pathlib.Path(path))

    @staticmethod
    def _load(path: pathlib.Path) -> set[str]:
        hosts: set[str] = set()
        for line in path.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            hosts.add(line.lower())
        return hosts

    def request(self, flow: http.HTTPFlow) -> None:
        host = flow.request.pretty_host.lower()
        if host in self.allowed:
            return
        flow.response = http.Response.make(
            403,
            b"Blocked: host not on unattended egress allowlist.\n",
            {"Content-Type": "text/plain"},
        )


addons = [BlockNonAllowlisted()]
PYEOF

chown "$PROXY_USER:$PROXY_USER" "$ADDON_FILE"

# --- Generate mitmproxy CA (runs once) ---

if [[ ! -f "$MITMPROXY_DIR/mitmproxy-ca-cert.pem" ]]; then
    log_info "Generating mitmproxy CA..."
    sudo -u "$PROXY_USER" HOME="$MITMPROXY_DIR" mitmdump --set confdir="$MITMPROXY_DIR" --quiet &
    MITMPID=$!
    # Wait for CA files to appear (mitmdump creates them on startup).
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        [[ -f "$MITMPROXY_DIR/mitmproxy-ca-cert.pem" ]] && break
        sleep 1
    done
    kill "$MITMPID" 2>/dev/null || true
    wait "$MITMPID" 2>/dev/null || true
fi

# --- Trust the CA system-wide so HTTPS clients accept the proxy ---

if [[ -f "$MITMPROXY_DIR/mitmproxy-ca-cert.pem" ]]; then
    install -m 644 "$MITMPROXY_DIR/mitmproxy-ca-cert.pem" /usr/local/share/ca-certificates/mitmproxy-unattended.crt
    update-ca-certificates --fresh >/dev/null
    log_info "Trusted mitmproxy CA system-wide."
else
    log_warn "CA file not generated; HTTPS through the proxy will fail until mitmdump runs once."
fi

# --- Systemd unit so the proxy starts with the container ---

cat > "$SYSTEMD_UNIT" <<UNIT
[Unit]
Description=Unattended egress proxy (mitmproxy)
After=network.target

[Service]
Type=simple
User=$PROXY_USER
Group=$PROXY_USER
Environment=UNATTENDED_ALLOWLIST=$ALLOWLIST_FILE
ExecStart=/usr/local/bin/mitmdump \\
    --set confdir=$MITMPROXY_DIR \\
    --listen-port $PROXY_PORT \\
    --save-stream-file $MITMPROXY_DIR/egress.mitm \\
    -s $ADDON_FILE
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

if command -v systemctl &>/dev/null; then
    systemctl daemon-reload
    systemctl enable --now mitmproxy-unattended.service 2>/dev/null || \
        log_warn "systemd unavailable; start mitmdump manually with: mitmdump -s $ADDON_FILE --listen-port $PROXY_PORT"
fi

# --- Profile snippet: point every shell at the proxy ---

cat > "$PROFILE_SNIPPET" <<PROFILE
# Injected by bootstrap/unattended-proxy.sh -- egress runs through a local
# allowlist proxy. If you unset these, outbound HTTPS will fail the block.
export HTTP_PROXY="http://127.0.0.1:$PROXY_PORT"
export HTTPS_PROXY="http://127.0.0.1:$PROXY_PORT"
export http_proxy="\$HTTP_PROXY"
export https_proxy="\$HTTPS_PROXY"
export NO_PROXY="localhost,127.0.0.1,::1"
export no_proxy="\$NO_PROXY"
# Some Python libs look at this instead of REQUESTS_CA_BUNDLE.
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
PROFILE
chmod 644 "$PROFILE_SNIPPET"

# --- iptables belt-and-suspenders (requires NET_ADMIN) ---

if iptables -L >/dev/null 2>&1; then
    log_info "Installing iptables rules to force traffic through the proxy..."
    # Allow loopback (the proxy listens there).
    iptables -C OUTPUT -o lo -j ACCEPT 2>/dev/null || iptables -I OUTPUT 1 -o lo -j ACCEPT
    # Allow the proxy's own outbound traffic (so mitmproxy can reach real hosts).
    proxy_uid=$(id -u "$PROXY_USER")
    iptables -C OUTPUT -m owner --uid-owner "$proxy_uid" -j ACCEPT 2>/dev/null || \
        iptables -I OUTPUT 2 -m owner --uid-owner "$proxy_uid" -j ACCEPT
    # Drop direct :80/:443 from everyone else (libraries that ignore HTTPS_PROXY).
    iptables -C OUTPUT -p tcp --dport 80 -j REJECT 2>/dev/null || \
        iptables -A OUTPUT -p tcp --dport 80 -j REJECT
    iptables -C OUTPUT -p tcp --dport 443 -j REJECT 2>/dev/null || \
        iptables -A OUTPUT -p tcp --dport 443 -j REJECT
else
    log_warn "iptables unavailable (no NET_ADMIN?). Egress control depends on HTTPS_PROXY env vars only."
    log_warn "A library that ignores HTTPS_PROXY can still reach arbitrary hosts."
fi

log_info "Unattended proxy setup complete."
log_info "Allowlist: $ALLOWLIST_FILE"
log_info "Logs:      $MITMPROXY_DIR/egress.mitm"
log_info "Proxy:     http://127.0.0.1:$PROXY_PORT"
