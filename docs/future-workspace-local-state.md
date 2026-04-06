# Future: Workspace-Local State Persistence

## Problem

The volume mount in `devcontainer.json` is the last required piece of boilerplate for devcontainer users:

```json
"mounts": [
  "source=${devcontainerId}-state,target=/home/vscode/.dotfiles-state,type=volume"
]
```

Docker named volumes must be declared before the container starts -- `install.sh` runs inside the container and cannot create them. This means users must manually add this line to every project's `devcontainer.json`.

## Proposal: Three-Tier State Persistence

Detect the best available persistence mechanism at runtime, with automatic fallback:

| Priority | Condition | Tier | Behavior |
|----------|-----------|------|----------|
| 1 | `~/.dotfiles-state` exists | **volume** | Use as-is (current behavior) |
| 2 | Workspace folder detected and writable | **workspace** | Create `<workspace>/.dotfiles-state/`, symlink `~/.dotfiles-state` to it, add `.gitignore` entry |
| 3 | Fallback | **ephemeral** | `mkdir ~/.dotfiles-state` (state lost on rebuild) |

With this, a user who configures dotfiles in VS Code settings gets persistent AI tool state in devcontainers with zero `devcontainer.json` changes.

## Codespaces Persistence Model

In GitHub Codespaces, workspace-local state is actually **more persistent** than Docker volumes:

| Operation | `/workspaces` | Docker volumes | Home (`~`) |
|-----------|:---:|:---:|:---:|
| Stop/start | survives | survives | survives |
| Standard rebuild | survives | survives | **wiped** |
| Full rebuild (`--full`) | survives | **wiped** | **wiped** |

This means the workspace-local tier would be the most reliable persistence option in Codespaces, superior to the volume mount approach.

For standard VS Code devcontainers, both named volumes and workspace bind mounts persist across rebuilds. The volume approach keeps state outside the project tree (cleaner), while workspace-local keeps it alongside project files (simpler).

## Implementation Sketch

### `bootstrap/detect.sh` -- Add `detect_workspace_folder()`

```bash
detect_workspace_folder() {
    # 1. Explicit override
    if [[ -n "${CONTAINER_WORKSPACE_FOLDER:-}" ]]; then
        echo "$CONTAINER_WORKSPACE_FOLDER"; return
    fi
    # 2. Self-edit mode (dotfiles repo IS the workspace)
    if is_dotfiles_workspace; then
        echo "$DOTFILES_DIR"; return
    fi
    # 3. Standard devcontainer: single dir under /workspaces/
    if [[ -d /workspaces ]]; then
        local candidates=(/workspaces/*/)
        if [[ ${#candidates[@]} -eq 1 && -d "${candidates[0]}" ]]; then
            echo "${candidates[0]%/}"; return
        fi
    fi
    echo ""
}
```

### `bootstrap/symlinks.sh` -- Add `detect_state_tier()`

```bash
detect_state_tier() {
    if [[ -d "$HOME/.dotfiles-state" ]]; then
        STATE_DIR="$HOME/.dotfiles-state"
        STATE_TIER="volume"
        return
    fi
    local ws_folder
    ws_folder=$(detect_workspace_folder)
    if [[ -n "$ws_folder" && -d "$ws_folder" ]]; then
        local ws_state="$ws_folder/.dotfiles-state"
        if mkdir -p "$ws_state" 2>/dev/null; then
            ln -snf "$ws_state" "$HOME/.dotfiles-state"
            STATE_DIR="$HOME/.dotfiles-state"
            STATE_TIER="workspace"
            _ensure_gitignore "$ws_folder" ".dotfiles-state/"
            return
        fi
    fi
    mkdir -p "$HOME/.dotfiles-state"
    STATE_DIR="$HOME/.dotfiles-state"
    STATE_TIER="ephemeral"
}
```

### `.gitignore` management

The `_ensure_gitignore()` helper idempotently appends `.dotfiles-state/` to the workspace's `.gitignore`. Uses `grep -qxF` to avoid duplicates.

## Status: Implemented

This feature was implemented with the following functions in `bootstrap/symlinks.sh`:
- `detect_state_tier()` -- four-tier detection: volume > codespaces > workspace-local > ephemeral
- `_ensure_gitignore()` -- idempotent `.gitignore` entry management

And in `bootstrap/detect.sh`:
- `detect_workspace_folder()` -- detects the container workspace path

The Codespaces tier uses `/workspaces/.codespaces/.persistedshare/dotfiles-state/` which is more persistent than Docker volumes (survives full rebuilds). No `devcontainer.json` configuration is needed for state persistence.
