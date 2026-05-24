#!/usr/bin/env bash
# devcontainer-egress.sh -- Opt-in iptables egress allowlist for devcontainers.
#
# Installs a DOTFILES-EGRESS custom chain on the OUTPUT chain that allows only:
#   - loopback (any port)
#   - established/related connections (return traffic)
#   - DNS (UDP/TCP 53)
#   - Anthropic + GitHub + package registries (resolved to IPs at install time)
#   - Hosts in DOTFILES_EGRESS_EXTRA_HOSTS (comma-separated)
# Anything else is REJECTed with icmp-host-prohibited (clean errors, not hangs).
#
# Using a custom chain (rather than -P OUTPUT DROP) lets this coexist with
# other tools that install OUTPUT rules (e.g. agentic/bootstrap/unattended-proxy.sh).
#
# Gates (all required, else exits 0 with reason logged):
#   1. DOTFILES_DEVCONTAINER_EGRESS=1
#   2. is_devcontainer() returns true
#   3. DOTFILES_NO_AI_TOOLS != 1
#   4. iptables userspace binary present (Codespaces base image gap)
#   5. NET_ADMIN capability (iptables -L must succeed under sudo)
#
# Safe to wire unconditionally into install.sh -- exits 0 on gate failure.
#
# Re-runnable: rebuilds the DOTFILES-EGRESS chain from scratch each time.
# Pinned IPs are refreshed by re-running the script (DNS changes are not
# tracked at runtime).
#
# Teardown (manual): rebuild the container, or run
#   sudo iptables -D OUTPUT -j DOTFILES-EGRESS
#   sudo iptables -F DOTFILES-EGRESS
#   sudo iptables -X DOTFILES-EGRESS
# Repeat with ip6tables if installed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# shellcheck source=./logging.sh
source "$DOTFILES_DIR/bootstrap/logging.sh"
# shellcheck source=./detect.sh
source "$DOTFILES_DIR/bootstrap/detect.sh"

CHAIN_NAME="${DOTFILES_EGRESS_CHAIN:-DOTFILES-EGRESS}"

DEFAULT_HOSTS=(
    # --- Anthropic ---
    api.anthropic.com
    console.anthropic.com
    statsig.anthropic.com
    # --- GitHub (git, gh CLI, raw, releases, container registry) ---
    github.com
    api.github.com
    codeload.github.com
    objects.githubusercontent.com
    raw.githubusercontent.com
    uploads.github.com
    ghcr.io
    # --- Package registries ---
    registry.npmjs.org
    registry.yarnpkg.com
    pypi.org
    files.pythonhosted.org
    crates.io
    static.crates.io
    index.crates.io
    proxy.golang.org
    sum.golang.org
)

_skip() {
    log_info "devcontainer-egress: $1"
    exit 0
}

_have() { command -v "$1" >/dev/null 2>&1; }

_iptables_works() {
    local cmd="$1"
    # NET_ADMIN required even to list. Prefer non-sudo so we can detect a
    # rootless setup; fall back to sudo -n if sudo is passwordless.
    "$cmd" -L OUTPUT >/dev/null 2>&1 && { SUDO=""; return 0; }
    sudo -n "$cmd" -L OUTPUT >/dev/null 2>&1 && { SUDO="sudo"; return 0; }
    return 1
}

# Install iptables if missing AND we have a package manager + sudo.
# Codespaces' mcr.microsoft.com/devcontainers/base:ubuntu image lacks the
# iptables userspace binary by default; the kernel netfilter modules are
# present but unusable without it.
_install_iptables() {
    _have iptables && return 0
    log_info "devcontainer-egress: iptables not found; attempting install"
    if [[ -f /etc/debian_version ]] && _have apt-get; then
        sudo -n apt-get update -qq 2>/dev/null || {
            log_warn "  apt-get update failed (no passwordless sudo?)"
            return 1
        }
        sudo -n apt-get install -y --no-install-recommends iptables >/dev/null 2>&1 || {
            log_warn "  apt-get install iptables failed"
            return 1
        }
    elif _have apk; then
        sudo -n apk add --no-cache iptables >/dev/null 2>&1 || {
            log_warn "  apk add iptables failed"
            return 1
        }
    else
        log_warn "  no apt-get or apk; cannot auto-install iptables"
        log_warn "  add 'iptables' to your devcontainer's package install step"
        return 1
    fi
    _have iptables
}

# Build (or rebuild) the egress chain on a given iptables binary (iptables / ip6tables).
_install_chain() {
    local ipt="$1"
    shift
    local -a ips=("$@")

    # Create chain if absent; flush if present (idempotent rebuild).
    if ! $SUDO "$ipt" -L "$CHAIN_NAME" >/dev/null 2>&1; then
        $SUDO "$ipt" -N "$CHAIN_NAME"
    fi
    $SUDO "$ipt" -F "$CHAIN_NAME"

    # Allow loopback.
    $SUDO "$ipt" -A "$CHAIN_NAME" -o lo -j ACCEPT
    # Allow return traffic.
    $SUDO "$ipt" -A "$CHAIN_NAME" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    # Allow DNS (resolver lives outside the chain's scope; without this no
    # subsequent name resolution works).
    $SUDO "$ipt" -A "$CHAIN_NAME" -p udp --dport 53 -j ACCEPT
    $SUDO "$ipt" -A "$CHAIN_NAME" -p tcp --dport 53 -j ACCEPT

    # Per-IP ACCEPT for each resolved allowlist host.
    local ip
    for ip in "${ips[@]}"; do
        [[ -z "$ip" ]] && continue
        $SUDO "$ipt" -A "$CHAIN_NAME" -d "$ip" -j ACCEPT
    done

    # End of chain: reject. Using REJECT (not DROP) so clients get a clean
    # error instead of hanging on connect.
    if [[ "$ipt" == "ip6tables" ]]; then
        $SUDO "$ipt" -A "$CHAIN_NAME" -j REJECT --reject-with icmp6-adm-prohibited
    else
        $SUDO "$ipt" -A "$CHAIN_NAME" -j REJECT --reject-with icmp-host-prohibited
    fi

    # Wire chain into OUTPUT (idempotent).
    if ! $SUDO "$ipt" -C OUTPUT -j "$CHAIN_NAME" 2>/dev/null; then
        $SUDO "$ipt" -I OUTPUT 1 -j "$CHAIN_NAME"
    fi
}

main() {
    if [[ "${DOTFILES_DEVCONTAINER_EGRESS:-}" != "1" ]]; then
        _skip "DOTFILES_DEVCONTAINER_EGRESS not set, skipping"
    fi
    if ! is_devcontainer; then
        _skip "not in a devcontainer, skipping"
    fi
    if [[ "${DOTFILES_NO_AI_TOOLS:-}" == "1" ]]; then
        _skip "DOTFILES_NO_AI_TOOLS=1, skipping"
    fi

    if ! _have iptables; then
        _install_iptables || _skip "iptables unavailable (see warnings above)"
    fi
    if ! _iptables_works iptables; then
        log_warn "devcontainer-egress: iptables -L OUTPUT denied"
        log_warn "  add '--cap-add=NET_ADMIN' to runArgs in devcontainer.json"
        exit 0
    fi

    log_section "devcontainer-egress: installing iptables OUTPUT allowlist"

    # Assemble host list.
    local -a hosts=("${DEFAULT_HOSTS[@]}")
    if [[ -n "${DOTFILES_EGRESS_EXTRA_HOSTS:-}" ]]; then
        local IFS=,
        # shellcheck disable=SC2206  # intentional word-split on comma
        local -a extras=(${DOTFILES_EGRESS_EXTRA_HOSTS})
        unset IFS
        local h
        for h in "${extras[@]}"; do
            h="${h// /}"
            [[ -n "$h" ]] && hosts+=("$h")
        done
        log_info "Extra hosts (DOTFILES_EGRESS_EXTRA_HOSTS): ${extras[*]}"
    fi

    # Resolve each host to v4 + v6 IPs. getent ahosts returns both families.
    local -a v4_ips=()
    local -a v6_ips=()
    local host ip family
    for host in "${hosts[@]}"; do
        local count4=0 count6=0
        while read -r ip family _; do
            [[ -z "$ip" ]] && continue
            case "$family" in
                STREAM|"") :;;  # only one row per (ip, family) on STREAM
                *) continue;;
            esac
            if [[ "$ip" == *:* ]]; then
                v6_ips+=("$ip")
                count6=$((count6 + 1))
            else
                v4_ips+=("$ip")
                count4=$((count4 + 1))
            fi
        done < <(getent ahosts "$host" 2>/dev/null | awk '!seen[$1]++')
        if (( count4 + count6 == 0 )); then
            log_warn "  $host: no DNS records, skipping"
        else
            log_info "  $host -> ${count4} v4, ${count6} v6"
        fi
    done

    # Dedupe.
    if ((${#v4_ips[@]} > 0)); then
        mapfile -t v4_ips < <(printf '%s\n' "${v4_ips[@]}" | sort -u)
    fi
    if ((${#v6_ips[@]} > 0)); then
        mapfile -t v6_ips < <(printf '%s\n' "${v6_ips[@]}" | sort -u)
    fi

    # IPv4 chain.
    _install_chain iptables "${v4_ips[@]}"
    log_success "devcontainer-egress: ${#v4_ips[@]} IPv4 destinations allowed"

    # IPv6 chain (best-effort: not all containers have IPv6).
    if _have ip6tables && _iptables_works ip6tables; then
        _install_chain ip6tables "${v6_ips[@]}"
        log_success "devcontainer-egress: ${#v6_ips[@]} IPv6 destinations allowed"
    else
        log_info "devcontainer-egress: ip6tables unavailable, skipping IPv6"
    fi

    log_info "devcontainer-egress: re-run after DNS changes to refresh pinned IPs"
}

# Only execute when run directly (not when sourced for testing).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
