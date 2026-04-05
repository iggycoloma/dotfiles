# Future: Workspace-Local State Persistence

## Problem

The volume mount in `devcontainer.json` is the last required piece of boilerplate for devcontainer users:

```json
"mounts": [
  "source=${devcontainerId}-state,target=/home/vscode/.devcontainer-state,type=volume"
]
```

Docker named volumes must be declared before the container starts -- `install.sh` runs inside the container and cannot create them. This means users must manually add this line to every project's `devcontainer.json`.

## Proposal: Three-Tier State Persistence

Detect the best available persistence mechanism at runtime, with automatic fallback:

| Priority | Condition | Tier | Behavior |
|----------|-----------|------|----------|
| 1 | `~/.devcontainer-state` exists | **volume** | Use as-is (current behavior) |
| 2 | Workspace folder detected and writable | **workspace** | Create `<workspace>/.devcontainer-state/`, symlink `~/.devcontainer-state` to it, add `.gitignore` entry |
| 3 | Fallback | **ephemeral** | `mkdir ~/.devcontainer-state` (state lost on rebuild) |

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
    if [[ -d "$HOME/.devcontainer-state" ]]; then
        STATE_DIR="$HOME/.devcontainer-state"
        STATE_TIER="volume"
        return
    fi
    local ws_folder
    ws_folder=$(detect_workspace_folder)
    if [[ -n "$ws_folder" && -d "$ws_folder" ]]; then
        local ws_state="$ws_folder/.devcontainer-state"
        if mkdir -p "$ws_state" 2>/dev/null; then
            ln -snf "$ws_state" "$HOME/.devcontainer-state"
            STATE_DIR="$HOME/.devcontainer-state"
            STATE_TIER="workspace"
            _ensure_gitignore "$ws_folder" ".devcontainer-state/"
            return
        fi
    fi
    mkdir -p "$HOME/.devcontainer-state"
    STATE_DIR="$HOME/.devcontainer-state"
    STATE_TIER="ephemeral"
}
```

### `.gitignore` management

The `_ensure_gitignore()` helper idempotently appends `.devcontainer-state/` to the workspace's `.gitignore`. Uses `grep -qxF` to avoid duplicates.

## Why Deferred

- Adds ~30 lines of detection/fallback logic
- Requires `.gitignore` management (modifying files in user's project)
- Workspace detection heuristic may need edge-case handling (multi-root workspaces, atypical mount points)
- The volume mount line is a reasonable one-line requirement for now

## When to Implement

Consider implementing when:
- Codespaces becomes a primary target environment
- Users report friction with the volume mount requirement
- The workspace detection heuristic can be validated across more environments
