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
