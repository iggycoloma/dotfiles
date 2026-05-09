# Feature Specification: Devcontainer Support

**Branch**: `009-devcontainer-support` | **Date**: 2026-04-01 | **Status**: Implemented

## User Scenarios & Testing

### User Story 1 - Codespaces auto-uses persisted share (Priority: P1)

A developer opens a Codespace and gets all their state (Claude
credentials, gh auth, atuin history) restored automatically across
rebuilds without configuring anything.

**Independent Test**: Open a Codespace, log in to Claude, rebuild the
container, assert Claude is still logged in.

**Acceptance Scenarios**:
```
GIVEN a Codespace with CODESPACES=true set
  AND no ~/.dotfiles-state directory yet
WHEN ./install.sh runs
THEN detect_state_tier returns "codespaces"
  AND STATE_PATH=/workspaces/.codespaces/.persistedshare/dotfiles-state
  AND ~/.dotfiles-state symlinks to that path
  AND chmod 700 the target
```

```
GIVEN a Codespace where Claude Code is authenticated and the
container is rebuilt
WHEN the user opens Claude Code
THEN credentials persist (~/.claude is volume-backed)
  AND no re-authentication is required
```

### User Story 2 - Local devcontainer with volume mount (Priority: P1)

A developer with a local devcontainer that has the recommended volume
mount gets the volume tier, and state survives rebuilds.

**Independent Test**: Add the recommended `mounts` line to
devcontainer.json, rebuild, write a sentinel file to
`~/.dotfiles-state/`, rebuild again, assert sentinel persists.

**Acceptance Scenarios**:
```
GIVEN local devcontainer with mounts: ["source=${devcontainerId}-state,
  target=/home/vscode/.dotfiles-state,type=volume"]
WHEN ./install.sh runs
THEN detect_state_tier returns "volume"
  AND no symlinking is needed (real directory already mounted)
  AND chmod 700 applied
```

### User Story 3 - Ephemeral fallback with helpful logging (Priority: P2)

A developer running a local devcontainer without the volume mount gets
a working install with state in `~/.dotfiles-state/`, plus a log line
showing the mount snippet to add to `devcontainer.json`.

**Acceptance Scenarios**:
```
GIVEN a local devcontainer with no volume at ~/.dotfiles-state
WHEN ./install.sh runs
THEN tier detection returns "ephemeral"
  AND ~/.dotfiles-state is created with chmod 700
  AND the installer logs the recommended `mounts` line
  AND credentials/sessions work but are lost on rebuild
```

### User Story 4 - Native AI tool install (Priority: P1)

In devcontainers and Codespaces, the installer drops Claude Code and
Codex CLI as native binaries. No devcontainer features required, no
Node.js required.

**Acceptance Scenarios**:
```
GIVEN a fresh devcontainer with no Node.js installed
WHEN ./install.sh runs
THEN claude is installed as a native binary in ~/.local/bin/
  AND codex is installed as a native binary
  AND `claude --version` and `codex --version` work
  AND no devcontainer feature was required
```

### Edge Cases

- **Codespaces persistedshare unwritable**: fall back to ephemeral
  with a warning.
- **Volume present but root-owned**: installer chowns to current user
  before setup.
- **`DOTFILES_NO_STATE_PERSISTENCE=1`**: skip all state setup;
  config still deploys.
- **Volume + Codespaces both apparent**: volume tier wins
  (real-directory check).

## Requirements

### Functional Requirements

- **FR-001** Installer MUST treat `CODESPACES=true` as Codespaces and
  `REMOTE_CONTAINERS=true` as devcontainer.
- **FR-002** `is_minimal_install` MUST return true for both.
- **FR-003** In devcontainers/Codespaces, Claude Code and Codex MUST
  install as native binaries (no Node.js dependency).
- **FR-004** `detect_state_tier` MUST be pure (no side effects).
- **FR-005** `setup_state_persistence` MUST handle each tier per the
  spec's tier semantics.
- **FR-006** `DOTFILES_NO_STATE_PERSISTENCE=1` MUST skip all state
  setup.
- **FR-007** Per-AI-tool config dirs (~/.claude, ~/.codex,
  ~/.copilot, ~/.config/gh) MUST be wired to volume-backed paths via
  directory symlinks when state persistence is available.
- **FR-008** Volume-backed setup MUST migrate existing real-directory
  contents into the volume on first run.
- **FR-009** Installer MUST chown ~/.dotfiles-state to current user
  if root-owned.
- **FR-010** State directory MUST be chmod 700.
- **FR-011** AI-tool config files (settings.json, CLAUDE.md, hooks,
  agents, commands) MUST be force-copied on every container start.
- **FR-012** Persistent state (auth tokens, session data, history)
  MUST NOT be touched by the per-boot config refresh.

### Key Entities

- **State tier**: `volume | codespaces | ephemeral` (tagged enum).
- **Volume-backed dir**: directory symlink from canonical path
  (e.g. `~/.claude`) to a state-backed path
  (e.g. `~/.dotfiles-state/claude/`).

## Success Criteria

- **SC-001** Cold install in a Codespace persists Claude credentials
  across one rebuild (CI integration test).
- **SC-002** Local devcontainer with volume mount: state persists
  across 3 simulated rebuilds.
- **SC-003** Ephemeral fallback never breaks the install (only state
  loss).
- **SC-004** Native AI tool install: < 10s overhead vs. host install
  (binaries pre-built; no compilation).
- **SC-005** All four scenarios (volume / codespaces / ephemeral /
  no-state) validated in CI.

## Assumptions

- VS Code's volume-mount syntax in `devcontainer.json` remains
  stable.
- GitHub Codespaces continues to expose `/workspaces/.codespaces/
  .persistedshare/` for state.
- Claude Code's credential storage path (`~/.claude/.credentials.json`)
  remains stable.
- Users do not symlink `~/.dotfiles-state` to a non-state path; if
  they do, the volume detection will incorrectly treat the symlink
  target as the volume.
