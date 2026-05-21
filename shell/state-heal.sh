#!/usr/bin/env bash
# Self-heal dotfiles-state volume desync.
#
# In devcontainers, tool config directories are symlinked into the persistent
# ~/.dotfiles-state volume by bootstrap/symlinks.sh:
#
#   ~/.claude     -> ~/.dotfiles-state/claude
#   ~/.codex      -> ~/.dotfiles-state/codex
#   ~/.copilot    -> ~/.dotfiles-state/copilot
#   ~/.config/gh  -> ~/.dotfiles-state/gh
#
# Bootstrap creates the volume-side directories, but only while it runs. If the
# state volume is remounted or replaced without re-running bootstrap, those
# symlinks dangle and the tool silently fails to write -- e.g. gh cannot
# persist its hosts.yml, so authentication is lost. This guard recreates any
# missing target directory on shell startup, healing a desync before the tool
# is used. Run `_heal_dotfiles_state` by hand to force a check.
#
# Keep the link list in sync with bootstrap/symlinks.sh (the _wire_tool_dir
# calls plus the explicit gh block).

_heal_dotfiles_state() {
    local state_dir link target
    state_dir="$HOME/.dotfiles-state"

    # Only relevant when the state volume is present (devcontainers).
    [ -d "$state_dir" ] || return 0

    for link in \
        "$HOME/.claude" \
        "$HOME/.codex" \
        "$HOME/.copilot" \
        "$HOME/.config/gh"
    do
        # Act only on a dangling symlink: a symlink (-L) whose target does not
        # resolve (-e follows the link).
        if [ -L "$link" ] && [ ! -e "$link" ]; then
            # Recreate the target only when it lives inside the state volume,
            # so a symlink pointing elsewhere can never make us create
            # arbitrary paths.
            target=$(readlink "$link")
            case "$target" in
                "$state_dir"/*) mkdir -p "$target" ;;
            esac
        fi
    done
}

_heal_dotfiles_state
