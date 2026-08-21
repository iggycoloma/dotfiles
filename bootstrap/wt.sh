#!/usr/bin/env bash
# Install wt (worktree-orchestrator) from its own repository.
#
# wt used to live in this repo as bin/wt; it is now a standalone tool at
# https://github.com/iggycoloma/worktree-orchestrator so it can be shared
# beyond dotfiles. This step keeps a managed clone under XDG data and runs
# the repo's own install.sh from it, which owns the ~/.local/bin/wt symlink
# that shell init, the wt shell function, and the worktree hooks all
# expect. Zsh completions for dotfiles' own fpath dir are linked separately
# by bootstrap/completions.sh.

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/bootstrap/logging.sh"

WT_ORCH_REPO="${WT_ORCH_REPO:-https://github.com/iggycoloma/worktree-orchestrator.git}"
WT_ORCH_DIR="${WT_ORCH_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/worktree-orchestrator}"

install_wt() {
    # -e, not -d: a worktree-style checkout (an orchestration main/ made by
    # wt convert included) has a .git pointer file, not a directory, and a
    # -d probe would fall through to cloning into a non-empty directory.
    if [[ -e "$WT_ORCH_DIR/.git" ]]; then
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

    if [[ ! -f "$WT_ORCH_DIR/install.sh" ]]; then
        log_error "wt: $WT_ORCH_DIR/install.sh missing (checkout too old or broken)"
        return 1
    fi

    # The repo's installer owns the symlink layout; run from the checkout it
    # installs from that checkout without cloning again.
    if ! bash "$WT_ORCH_DIR/install.sh"; then
        log_error "wt: install.sh failed"
        return 1
    fi
    log_success "wt installed from $WT_ORCH_DIR"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_wt
fi
