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
# If the state volume exists but is not writable (named volumes are created
# root-owned on first mount), a shell cannot heal it -- that needs ownership
# repair. In that case this prints an actionable warning rather than failing
# silently, since a silently broken volume means tools accept a login but
# cannot persist it.
#
# Keep the link list in sync with bootstrap/symlinks.sh (the _wire_tool_dir
# calls plus the explicit gh block).

_heal_dotfiles_state() {
    local state_dir link target
    state_dir="$HOME/.dotfiles-state"

    # Only relevant when the state volume is present (devcontainers).
    [ -d "$state_dir" ] || return 0

    # An unwritable volume cannot be healed without sudo, which must never run
    # from a shell startup (it could block on a password prompt). Warn instead.
    if [ ! -w "$state_dir" ]; then
        printf '%s\n' \
            "dotfiles: $state_dir is not writable -- gh/claude/codex state cannot persist." \
            "dotfiles: fix with: sudo chown -R \"\$(id -u):\$(id -g)\" $state_dir" >&2
        return 0
    fi

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
