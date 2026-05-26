#!/usr/bin/env bash
# Shared logging functions for dotfiles bootstrap scripts
# Source guard to prevent double-sourcing
[[ -n "${_DOTFILES_LOGGING_LOADED:-}" ]] && return 0
_DOTFILES_LOGGING_LOADED=1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}==>${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn()    { echo -e "${YELLOW}!${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }
log_section() { echo -e "\n${MAGENTA}==== $1 ====${NC}\n"; }

# log_and_return / log_and_exit: log at a severity then return/exit with a code.
# Used by scripts that have a recurring "log then fail" pattern. Cuts a
# two-line idiom to one line at the callsite and keeps the failure
# semantics consistent.
#
# Usage:
#   log_and_return error 2 "rubric not found"   # log_error + return 2
#   log_and_exit   warn  1 "missing required dependency"  # log_warn + exit 1
#
# Severity is one of: info, success, warn, error, section.
log_and_return() {
    local severity="$1" code="$2" message="$3"
    "log_$severity" "$message" >&2
    return "$code"
}

log_and_exit() {
    local severity="$1" code="$2" message="$3"
    "log_$severity" "$message" >&2
    exit "$code"
}
