#!/usr/bin/env bash
# prompt-drift.sh -- Verify deployed agent-instruction files match tracked sources.
#
# Tracked sources in this repo are authoritative; the copies under ~/.claude,
# ~/.codex, and ~/.copilot are outputs of bootstrap/symlinks.sh -- symlinks on
# hosts, managed copies in devcontainers. A managed copy goes stale between a
# source edit and the next rebuild; this catches that silently-drifted state.
#
# A pair passes when the deployed path is a symlink resolving to the tracked
# source, or when the contents are byte-identical. A deployed path that does
# not exist or is not readable is skipped: not every environment installs every
# tool, and ~/.copilot is unreadable inside the credential sandbox.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Derived unconditionally, unlike settings-drift.sh: the shell exports
# DOTFILES_DIR pointing at the main checkout, and honoring it from a worktree
# would compare the main checkout's sources instead of the tree under review.
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../bootstrap/logging.sh
source "$DOTFILES_DIR/bootstrap/logging.sh"

QUIET=false
[[ "${1:-}" == "--quiet" ]] && QUIET=true

ERRORS=0
CHECKED=0
SKIPPED=0

check_pair() {
    local src="$1" dst="$2"
    # -e dereferences symlinks, so test for the dangling case first: a deployed
    # symlink whose target vanished is a broken deployment, not "not deployed".
    if [[ -L "$dst" && ! -e "$dst" ]]; then
        log_error "DRIFT: $dst is a dangling symlink (tracked source moved or deleted)"
        ERRORS=$((ERRORS + 1))
        return 0
    fi
    if [[ ! -e "$dst" || ! -r "$dst" ]]; then
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi
    CHECKED=$((CHECKED + 1))

    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        $QUIET || log_success "symlink ok: $dst"
        return 0
    fi
    if cmp -s "$src" "$dst"; then
        $QUIET || log_success "copy ok: $dst"
        return 0
    fi

    log_error "DRIFT: $dst differs from tracked source $src"
    log_error "  Re-run install.sh (or bootstrap/symlinks.sh) to redeploy; never edit the deployed copy."
    ERRORS=$((ERRORS + 1))
}

check_pair "$DOTFILES_DIR/claude-code/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
check_pair "$DOTFILES_DIR/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
check_pair "$DOTFILES_DIR/copilot/copilot-instructions.md" "$HOME/.copilot/copilot-instructions.md"

for fragment in "$DOTFILES_DIR"/agent-prompts/*.md; do
    [[ -f "$fragment" ]] || continue
    name="$(basename "$fragment")"
    for tool_dir in "$HOME/.claude" "$HOME/.codex" "$HOME/.copilot"; do
        check_pair "$fragment" "$tool_dir/prompts/$name"
    done
done

for skill_dir in "$DOTFILES_DIR"/agent-skills/*; do
    [[ -d "$skill_dir" && -f "$skill_dir/SKILL.md" ]] || continue
    name="$(basename "$skill_dir")"
    check_pair "$skill_dir/SKILL.md" "$HOME/.claude/skills/$name/SKILL.md"
    check_pair "$skill_dir/SKILL.md" "$HOME/.codex/skills/$name/SKILL.md"
done

if [[ "$ERRORS" -gt 0 ]]; then
    log_error "prompt-drift: $ERRORS deployed instruction file(s) drifted from tracked sources"
    exit 1
fi
$QUIET || log_success "prompt-drift: $CHECKED deployed instruction file(s) match tracked sources ($SKIPPED not deployed here)"
