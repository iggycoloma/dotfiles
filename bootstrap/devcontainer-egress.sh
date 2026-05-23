#!/usr/bin/env bash
# Devcontainer egress allowlist.
#
# Restricts outbound network traffic from inside the container to a small
# set of agentic-tool and code-management endpoints, using iptables. Part
# of the three-tier sandbox model in docs/sandbox.md: hosts get bwrap +
# allowedDomains (kernel-enforced via netns); containers get the container
# boundary + this script.
#
# Gating (all must hold for the script to do anything):
#   1. DOTFILES_DEVCONTAINER_EGRESS=1 in the environment (default: off)
#   2. Running inside a devcontainer (is_devcontainer)
#   3. Container has NET_ADMIN capability (otherwise iptables would EPERM)
#   4. DOTFILES_NO_AI_TOOLS != 1
#
# Allowlist (added to OUTPUT chain as ACCEPT rules; everything else hits the
# terminal DROP). Resolve-at-script-time IPs; if endpoints add new IPs, the
# script must be re-run.
#   - api.anthropic.com, console.anthropic.com (model API + auth)
#   - github.com, api.github.com, codeload.github.com,
#     raw.githubusercontent.com, objects.githubusercontent.com (git + auth)
#   - registry.npmjs.org (npm)
#   - pypi.org, files.pythonhosted.org (pip)
#   - crates.io, static.crates.io (cargo)
#
# Project additions: set DOTFILES_EGRESS_EXTRA_HOSTS to a space-separated list
# of hostnames to extend the allowlist for your project (e.g. a private
# package registry). DNS, loopback, and RELATED/ESTABLISHED are always
# permitted regardless of allowlist.
#
# Idempotent: existing dotfiles-egress rules are flushed before re-adding.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# Logging + detection
if [[ -f "$DOTFILES_DIR/bootstrap/logging.sh" ]]; then
    # shellcheck disable=SC1091
    source "$DOTFILES_DIR/bootstrap/logging.sh"
else
    log_info() { printf '[egress] %s\n' "$*"; }
    log_warn() { printf '[egress] WARN: %s\n' "$*" >&2; }
    log_success() { printf '[egress] OK: %s\n' "$*"; }
fi
if [[ -f "$DOTFILES_DIR/bootstrap/detect.sh" ]]; then
    # shellcheck disable=SC1091
    source "$DOTFILES_DIR/bootstrap/detect.sh"
fi

COMMENT_TAG="dotfiles-egress"

# Quietly skip if not opted in.
if [[ "${DOTFILES_DEVCONTAINER_EGRESS:-0}" != "1" ]]; then
    exit 0
fi

# Skip if AI tools are opt-out (egress is part of agent-adjacent infra).
if [[ "${DOTFILES_NO_AI_TOOLS:-}" == "1" ]]; then
    log_info "Skipping egress allowlist (DOTFILES_NO_AI_TOOLS=1)"
    exit 0
fi

# Skip outside containers (this is a container-tier control).
if command -v is_devcontainer >/dev/null 2>&1 && ! is_devcontainer; then
    log_info "Skipping egress allowlist (not in a devcontainer)"
    exit 0
fi

# Capability check. iptables needs NET_ADMIN; without it every command EPERMs.
# Probe with a no-op listing command. sudo may be needed if iptables is not
# accessible as the unprivileged user.
_iptables() {
    if command -v sudo >/dev/null 2>&1; then
        sudo iptables "$@"
    else
        iptables "$@"
    fi
}

if ! _iptables -S OUTPUT >/dev/null 2>&1; then
    log_warn "iptables unavailable or NET_ADMIN missing -- egress allowlist skipped."
    log_info "To enable: add --cap-add=NET_ADMIN to runArgs in devcontainer.json."
    exit 0
fi

# Wipe any existing dotfiles-egress rules so the script is idempotent.
# Read the current OUTPUT chain, find rules tagged with our comment, build
# matching delete commands. Process in reverse order so indices stay valid.
existing=$(_iptables -S OUTPUT | grep -F "comment --comment \"$COMMENT_TAG" || true)
if [[ -n "$existing" ]]; then
    while IFS= read -r rule; do
        # Convert -A OUTPUT ... into -D OUTPUT ...
        del_rule="${rule/-A /-D }"
        # shellcheck disable=SC2086  # intentional word-split: iptables args
        _iptables $del_rule 2>/dev/null || true
    done <<< "$(echo "$existing" | tac)"
fi

# Always-allowed traffic: loopback, established connections, DNS.
_iptables -A OUTPUT -o lo -j ACCEPT \
    -m comment --comment "${COMMENT_TAG}:loopback"
_iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT \
    -m comment --comment "${COMMENT_TAG}:established"
_iptables -A OUTPUT -p udp --dport 53 -j ACCEPT \
    -m comment --comment "${COMMENT_TAG}:dns-udp"
_iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT \
    -m comment --comment "${COMMENT_TAG}:dns-tcp"

# Default hostname allowlist. Resolve each via getent and add ACCEPT rules
# for the matching IPs. If DNS fails for a host, log a warning but keep
# going; the user can re-run after connectivity returns.
ALLOW_HOSTS=(
    api.anthropic.com
    console.anthropic.com
    github.com
    api.github.com
    codeload.github.com
    raw.githubusercontent.com
    objects.githubusercontent.com
    registry.npmjs.org
    pypi.org
    files.pythonhosted.org
    crates.io
    static.crates.io
)

# Project-specific additions from DOTFILES_EGRESS_EXTRA_HOSTS (space-separated).
if [[ -n "${DOTFILES_EGRESS_EXTRA_HOSTS:-}" ]]; then
    # shellcheck disable=SC2206  # intentional word-split on whitespace
    extras=( ${DOTFILES_EGRESS_EXTRA_HOSTS} )
    ALLOW_HOSTS+=( "${extras[@]}" )
fi

added=0
for host in "${ALLOW_HOSTS[@]}"; do
    ips=$(getent hosts "$host" 2>/dev/null | awk '{print $1}' | sort -u)
    if [[ -z "$ips" ]]; then
        log_warn "DNS lookup failed for $host -- skipping"
        continue
    fi
    while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        _iptables -A OUTPUT -d "$ip" -j ACCEPT \
            -m comment --comment "${COMMENT_TAG}:${host}"
        added=$((added + 1))
    done <<< "$ips"
done

# Terminal DROP for anything not matched above. We use a rule with our tag
# (not the chain policy) so it is easy to remove without leaving the chain
# in a broken state if the script is later disabled.
_iptables -A OUTPUT -j DROP \
    -m comment --comment "${COMMENT_TAG}:default-drop"

log_success "Egress allowlist installed (${#ALLOW_HOSTS[@]} hosts, ${added} IPs)"
