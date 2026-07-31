#!/usr/bin/env bash
# Self-heal dotfiles-state volume desync.
#
# bootstrap/symlinks.sh points tool config dirs at the persistent
# ~/.dotfiles-state volume, but creates the volume-side directories only while
# it runs. Remount or replace the volume without re-running bootstrap and those
# symlinks dangle, at which point the tool silently fails to write -- gh cannot
# persist hosts.yml, so authentication is lost. Recreating the missing target
# at shell startup heals the desync before the tool is next used.
#
# The link list below must track the _wire_tool_dir calls in symlinks.sh.

_heal_dotfiles_state() {
    local state_dir link target
    state_dir="$HOME/.dotfiles-state"

    # Devcontainers only; hosts have no state volume.
    [ -d "$state_dir" ] || return 0

    # Ownership repair needs root, and sudo must never run at shell startup, so
    # warn rather than fail silently -- a broken volume lets tools accept a
    # login they cannot persist.
    if [ ! -w "$state_dir" ]; then
        printf 'dotfiles: %s is not writable -- gh/claude/codex auth cannot persist.\n' \
            "$state_dir" >&2
        if grep -qs '^NoNewPrivs:[[:space:]]*1' /proc/self/status; then
            printf 'dotfiles: sudo is blocked here (no_new_privs); rebuild the container, or from the host run:\n        docker exec -u 0 <container> chown -R %s:%s %s\n' \
                "$(id -u)" "$(id -g)" "$state_dir" >&2
        else
            printf 'dotfiles: fix with: sudo chown -R %s:%s %s\n' \
                "$(id -u)" "$(id -g)" "$state_dir" >&2
        fi
        return 0
    fi

    for link in \
        "$HOME/.claude" \
        "$HOME/.codex" \
        "$HOME/.copilot" \
        "$HOME/.config/gh" \
        "$HOME/.config/glab-cli"
    do
        # Dangling: a symlink whose target does not resolve.
        if [ -L "$link" ] && [ ! -e "$link" ]; then
            # Confined to the state volume, so a symlink pointing elsewhere
            # cannot make us create arbitrary paths.
            target=$(readlink "$link")
            case "$target" in
                "$state_dir"/*) mkdir -p "$target" ;;
            esac
        fi
    done
}

_heal_dotfiles_state
