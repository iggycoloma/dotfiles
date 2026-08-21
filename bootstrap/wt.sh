#!/usr/bin/env bash
# Install wt (worktree-orchestrator) from its own repository.
#
# wt used to live in this repo as bin/wt; it is now a standalone tool at
# https://github.com/iggycoloma/worktree-orchestrator so it can be shared
# beyond dotfiles. This step keeps a managed clone under XDG data and links
# the executable to ~/.local/bin/wt, where shell init, the wt shell
# function, and the worktree hooks all expect it. Completions come from the
# same clone, linked by bootstrap/completions.sh.

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/bootstrap/logging.sh"

WT_ORCH_REPO="${WT_ORCH_REPO:-https://github.com/iggycoloma/worktree-orchestrator.git}"
WT_ORCH_DIR="${WT_ORCH_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/worktree-orchestrator}"

install_wt() {
    if [[ -d "$WT_ORCH_DIR/.git" ]]; then
        # Re-runnable like the rest of install.sh: refresh the clone, but a
        # dirty or diverged tree (local development) is kept, not clobbered.
        if ! git -C "$WT_ORCH_DIR" pull --ff-only -q 2>/dev/null; then
            log_warn "wt: could not fast-forward $WT_ORCH_DIR; keeping the existing checkout"
        fi
    else
        log_info "Cloning worktree-orchestrator..."
        if ! git clone -q "$WT_ORCH_REPO" "$WT_ORCH_DIR"; then
            log_error "wt: clone failed: $WT_ORCH_REPO"
            return 1
        fi
    fi

    if [[ ! -x "$WT_ORCH_DIR/bin/wt" ]]; then
        log_error "wt: $WT_ORCH_DIR/bin/wt missing or not executable"
        return 1
    fi

    mkdir -p "$HOME/.local/bin"
    ln -sf "$WT_ORCH_DIR/bin/wt" "$HOME/.local/bin/wt"
    log_success "wt linked: ~/.local/bin/wt -> $WT_ORCH_DIR/bin/wt"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_wt
fi
