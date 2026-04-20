#!/usr/bin/env bash
# Validate GH_TOKEN scope before handing control to ralph in an unattended run.
#
# Why: the unattended devcontainer does not mount a persistent gh credential
# store. Callers pass GH_TOKEN via the environment for a single run. We want
# to (a) confirm the token is actually present, (b) confirm it can reach the
# target repo, and (c) discourage broad personal access tokens by checking
# the token's reachable scopes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./logging.sh
source "$SCRIPT_DIR/logging.sh"

target_repo="${GITHUB_REPOSITORY:-${1:-}}"

if [[ -z "${GH_TOKEN:-}" ]]; then
    log_error "GH_TOKEN is not set. Unattended runs need an explicit per-run token."
    log_error "Pass it via the devcontainer containerEnv / docker -e or export it before running."
    exit 2
fi

if [[ -z "$target_repo" ]]; then
    log_error "No target repo. Set GITHUB_REPOSITORY=owner/repo or pass owner/repo as an argument."
    exit 2
fi

if ! command -v gh &>/dev/null; then
    log_error "gh CLI not found. Install via the unattended devcontainer's github-cli feature."
    exit 2
fi

log_info "Validating GH_TOKEN against $target_repo..."
if ! gh api "/repos/$target_repo" --silent 2>/dev/null; then
    log_error "gh api /repos/$target_repo failed. Token is missing, invalid, or lacks access."
    exit 3
fi
log_info "Token can read $target_repo. OK."

# Scope hint: fine-grained tokens return an x-accepted-github-permissions header
# but we keep this check lightweight. Classic PATs often carry `repo` (all repos).
# Warn if the token exposes every repo the caller can see.
accessible_count=$(gh api '/user/repos?per_page=1&visibility=all' --include 2>/dev/null \
    | awk 'tolower($1)=="x-total-count:" {print $2}' | tr -d '\r' || true)

if [[ -n "$accessible_count" ]] && [[ "$accessible_count" =~ ^[0-9]+$ ]] && [[ $accessible_count -gt 5 ]]; then
    log_warn "This token can access $accessible_count repositories."
    log_warn "Prefer a fine-grained token scoped to $target_repo only."
fi

log_info "GH_TOKEN validation complete."
