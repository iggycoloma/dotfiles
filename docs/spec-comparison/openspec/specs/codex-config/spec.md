# codex-config

## Overview

Global Codex CLI configuration deployed to `~/.codex/`.
Mirrors the Claude Code guardrails (credential deny lists, conventional commits, no emoji, preferred CLI tools) and provides a "claude-parity" skill set so familiar intents map to equivalent workflows.
Adds a Pushover idle-notify hook.
Preserves any user-local `config.toml` (Codex trust state and preferences).

## Requirements

### Deployment

- The installer MUST deploy `AGENTS.md`, `hooks.json`, the `hooks/` directory, and the per-skill subdirectories of `skills/` from `<DOTFILES_DIR>/codex/` into `~/.codex/`.
- The installer MUST migrate from a legacy whole-directory symlink at `~/.codex` (older host installs) to managed individual files by removing the symlink first.
- The installer MUST deploy a `config.toml` chosen by environment via `_deploy_variant_file`: `config.toml` (host variant, `sandbox_mode = "workspace-write"`) is symlinked on hosts; `config.container.toml` (container variant, `sandbox_mode = "danger-full-access"`) is copied inside devcontainers.
  Both variants keep `approval_policy = "on-request"` -- the human-in-the-loop gate is identical in both; only the sandbox posture differs.
  Host: Codex sandboxes file writes to the workspace.
  Container: the container itself is the trust boundary; another sandbox would block legitimate work without adding isolation.
- The installer MUST preserve any pre-existing real `~/.codex/config.toml` on hosts (Codex stores trust state and per-machine preferences there).
- If neither variant is present at the target path, the installer MUST seed `~/.codex/config.toml` with the notify hook line and the environment-appropriate `approval_mode`.
- The installer MUST migrate the legacy `notify = "bash ..."` string format to the array form `notify = ["bash", "..."]`.

### AGENTS.md

- The deployed `AGENTS.md` MUST list the same credential deny lists as Claude Code's CLAUDE.md.
- The deployed `AGENTS.md` MUST forbid path traversal patterns.
- The deployed `AGENTS.md` MUST list the preferred CLI tools (rg, sg, fd, difft, sd, bat, scc, yq, jq, duf, dust, procs, hyperfine).
- The deployed `AGENTS.md` MUST forbid installing new MCP servers without explicit user request.

### Claude-parity skill

- `~/.codex/skills/claude-parity/` MUST map user intents to equivalent Claude Code workflows: `context-prime`, `commit`, `pr-create`, `review-pr`, `debug`, `test`, `dependencies`, `security-audit`, `feature-spec`, `pipeline`.
- The `pipeline` skill MUST replicate the 4-stage flow: PM Spec -> Architect Decision -> Implementer + Tests -> QA verification, with user checkpoints between stages.

### Notify hook

- `~/.codex/hooks/notify.sh` MUST send a Pushover notification when Codex becomes idle waiting for user input.
- The hook MUST be wired in `~/.codex/config.toml` via `notify = ["bash", "$HOME/.codex/hooks/notify.sh"]`.
- The hook MUST silently no-op if `PUSHOVER_TOKEN` and `PUSHOVER_USER` are not set.

### Shell aliases

- The shell aliases (deployed by the `shell` capability) MUST define `cx` -> `codex`, `cxe` -> `codex exec`, `cxr` -> `codex review --uncommitted`.

## Scenarios

### Scenario: Skill maps "commit" intent

GIVEN the user invokes Codex with intent matching "commit"
WHEN the claude-parity skill resolves the intent
THEN Codex inspects staged/unstaged diff
AND proposes a conventional commit message
AND runs `git commit` only after user confirms.

### Scenario: Notify hook fires when idle

GIVEN Codex is running with `PUSHOVER_TOKEN` and `PUSHOVER_USER` set
WHEN Codex finishes a step and waits for user input
THEN `~/.codex/hooks/notify.sh` runs
AND a Pushover notification reaches the user's phone within 5 seconds.

### Scenario: Legacy notify-string format migrated

GIVEN `~/.codex/config.toml` contains `notify = "bash /home/user/.codex/hooks/notify.sh"`
WHEN `./install.sh` runs
THEN the installer detects the string format
AND rewrites the line to `notify = ["bash", "/home/user/.codex/hooks/notify.sh"]`
AND logs `Fixing notify hook format in ~/.codex/config.toml (string -> array)`.

### Scenario: User config.toml preserved on host re-install

GIVEN a host install where the user has manually customized `~/.codex/config.toml`
AND the file is a real file (not a symlink)
WHEN `./install.sh` runs
THEN the installer logs `Skipping ~/.codex/config.toml (preserving local Codex settings)`
AND does not overwrite the file.

### Scenario: Devcontainer install picks the container Codex variant

GIVEN a devcontainer (`REMOTE_CONTAINERS=true`) running `./install.sh`
WHEN `_deploy_variant_file` runs for `config.toml`
THEN `~/.codex/config.toml` is a copy of `<DOTFILES_DIR>/codex/config.container.toml`
AND it sets `sandbox_mode = "danger-full-access"`
AND `approval_policy = "on-request"` is unchanged from the host variant
AND the trust boundary is the container itself.

## Non-Behavior

- The Codex config does NOT enforce `pre-security.sh`-style runtime blocking -- Codex's hook system is more limited; deny lists rely on AGENTS.md instructions to the model.
- The Codex config does NOT install Codex itself; the `packages` capability handles installation.
- The Codex config does NOT define skills beyond the claude-parity set (workflows for unrelated tools live in their own skill packs).
- The Codex config does NOT modify `config.toml` trust entries for any workspace (those are user-managed via `codex` itself).
