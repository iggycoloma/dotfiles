# devcontainer-support

## Overview

Auto-detection of VS Code devcontainer and GitHub Codespaces environments, native installation of agentic CLIs (no devcontainer features required), and a tiered state-persistence model that keeps credentials, shell history, and AI-tool sessions alive across container rebuilds.
Three persistence tiers: volume mount > Codespaces persisted-share > ephemeral fallback.

## Requirements

### Detection

- The installer MUST treat `CODESPACES=true` as a Codespaces environment and `REMOTE_CONTAINERS=true` as a devcontainer environment.
- The installer MUST treat the presence of `/.dockerenv` plus `${REMOTE_CONTAINERS:-}` set as a devcontainer.
- The installer MUST set `is_minimal_install` true for both `codespaces` and `devcontainer`, false otherwise.

### Native AI-tool install

- In devcontainers and Codespaces, the installer MUST install Claude Code and Codex CLI as native binaries (not via devcontainer features or Node.js).
- The installer MUST work without Node.js being present in the container.
- The installer MUST deploy the container variant of each AI-tool settings file (`settings.container.json`, `config.container.toml`) as a copy rather than a symlink so the dotfiles repo need not be present in the container at runtime.
  See `claude-code-config` and `codex-config` specs for the variant contract.

### Egress posture

- Attended devcontainers MUST NOT enforce network egress at the network layer.
  The trust posture for attended profiles is dc-audit spec-linting plus the container boundary (the user trusts the host the container runs on).
- The prior `bootstrap/devcontainer-egress.sh` iptables script and its `DOTFILES_DEVCONTAINER_EGRESS` / `DOTFILES_EGRESS_EXTRA_HOSTS` env vars MUST NOT exist; they were removed in favor of dc-audit rules.
- Unattended devcontainers (`.devcontainer/unattended/`) DO enforce egress via mitmproxy; see `unattended-harness` spec.

### State persistence: tier detection

- The installer MUST detect the best available persistence tier in `detect_state_tier`:
  - **Tier 1 (volume)**: `~/.dotfiles-state` exists as a real directory (not a symlink) -- a host-mounted Docker volume.
  - **Tier 2 (codespaces)**: `CODESPACES=true` -- use `/workspaces/.codespaces/.persistedshare/dotfiles-state/`.
  - **Tier 3 (ephemeral)**: fallback to `~/.dotfiles-state/`, lost on rebuild.
- Detection MUST be pure (no side effects); side effects happen in `setup_state_persistence`.

### State persistence: setup

- For Tier 1 (volume), no setup beyond chmod 700 -- the mount is already in place.
- For Tier 2 (Codespaces), the installer MUST `mkdir -p` the persistedshare directory, symlink `~/.dotfiles-state -> $STATE_PATH`, and chmod 700 the target.
- For Tier 3 (ephemeral), the installer MUST `mkdir -p ~/.dotfiles-state`, chmod 700, and log the volume-mount instructions the user can copy into their `devcontainer.json`.
- When `DOTFILES_NO_STATE_PERSISTENCE=1`, the installer MUST skip all state-persistence setup.

### Volume-backed config dirs

- In devcontainers with state persistence, the installer MUST point `~/.claude`, `~/.codex`, `~/.copilot`, and `~/.config/gh` at state-backed directories via directory symlinks (not file symlinks).
- The volume-backed setup MUST migrate any existing real-directory contents into the volume on first run, then replace the directory with a symlink.

### Permission hygiene

- After mounting `~/.dotfiles-state`, the installer MUST chown to the current user if the mount appears root-owned.
- The state directory MUST be chmod 700 (owner-only).

### Per-boot config refresh

- AI-tool config files (settings.json, CLAUDE.md, AGENTS.md, hooks, agents, commands, skills) MUST be force-copied on every container start so the container always reflects the current dotfiles.
- Persistent state (auth tokens, session data, shell history) MUST NOT be touched by the per-boot refresh.

## Scenarios

### Scenario: Codespaces auto-uses persisted share

GIVEN a Codespace with `CODESPACES=true` set
AND no `~/.dotfiles-state/` directory yet
WHEN `./install.sh` runs
THEN `detect_state_tier` returns `STATE_TIER=codespaces`
AND `STATE_PATH=/workspaces/.codespaces/.persistedshare/dotfiles-state`
AND `setup_state_persistence` creates the path
AND symlinks `~/.dotfiles-state -> /workspaces/.codespaces/.persistedshare/dotfiles-state`
AND chmod 700 the target.

### Scenario: Local devcontainer without volume mount falls back to ephemeral

GIVEN a local devcontainer with no volume mounted at `~/.dotfiles-state`
WHEN `./install.sh` runs
THEN tier detection returns `ephemeral`
AND the installer logs the recommended `mounts` line for `devcontainer.json`
AND credentials/sessions are stored in `~/.dotfiles-state/` but lost on rebuild.

### Scenario: Claude Code state survives rebuild on volume tier

GIVEN a local devcontainer with the volume mount configured
WHEN the user authenticates Claude Code (writes to `~/.claude/.credentials.json`)
AND rebuilds the container
THEN `~/.claude` symlinks to the volume directory
AND the credentials file persists
AND Claude Code does not require re-authentication.

### Scenario: AI config refreshed on rebuild

GIVEN a devcontainer rebuild
AND the previous container had a stale `~/.claude/settings.json`
WHEN `./install.sh` runs
THEN `stomp_configs` force-copies the current dotfiles `claude-code/settings.json` to `~/.claude/settings.json`
AND `~/.claude/.credentials.json` (state) is untouched (lives on the volume).

## Non-Behavior

- Workspace-local state persistence (`<project>/.dotfiles-state/`) is explicitly NOT supported.
  The security analysis in `docs/future-workspace-local-state.md` documents the rejection (credential exposure via backups, archive uploads, Dockerfile COPY, scanners, or accidental `git add -A`).
- The installer does NOT auto-add the volume mount to `devcontainer.json` -- it only logs the line for the user to add.
- The installer does NOT support encrypted state volumes (out of scope; Docker volume encryption is the user's call).
- The installer does NOT migrate state between tiers when the tier changes (e.g. volume -> ephemeral on remount); the user gets a fresh ephemeral state.
