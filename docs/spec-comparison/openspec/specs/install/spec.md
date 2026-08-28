# install

## Overview

Single-entrypoint installer that detects the host environment, installs CLI tools and configuration, and is safe to re-run any number of times.
The canonical entrypoint is `./install.sh` at the repo root.
It accepts only one flag (`--with-unattended`/`--without-unattended`) and a small set of `DOTFILES_*` opt-out environment variables.

## Requirements

### Entrypoint and CLI surface

- `install.sh` MUST run with `bash` (POSIX-compatible) and MUST set `set -u` early so undefined variables fail fast.
- `install.sh` MUST accept `--with-unattended` (alias for `DOTFILES_INSTALL_UNATTENDED=1`) and `--without-unattended` (alias for `DOTFILES_INSTALL_UNATTENDED=0`).
- `install.sh` MUST accept `-h` and `--help` and print usage including the `--with-unattended` flag.
- `install.sh` MUST tolerate unknown positional arguments without failing (older CI callers may pass env vars positionally).

### Environment detection

- The installer MUST detect `codespaces` when `CODESPACES` is set, `devcontainer` when `REMOTE_CONTAINERS` is set, `remote` when an SSH connection is detected, otherwise `local`.
- The installer MUST detect the OS as one of `macos`, `debian`, `alpine`, `linux`, or `unknown` based on `OSTYPE` and `/etc/os-release`.
- The installer MUST detect the package manager as one of `brew`, `apt`, `apk`, or `none`.
- `is_minimal_install` MUST return true for `codespaces` and `devcontainer`, false otherwise.
  It MUST be a thin alias for `is_devcontainer` -- the installer keeps both names for caller intent (deployment scope vs. environment shape) but they MUST not diverge in behavior.

### Symlink and config deployment

- The installer MUST back up any pre-existing real file or directory at the target path to `~/.dotfiles_backup_<timestamp>/` before replacing it.
- The installer MUST replace existing symlinks without backup (they are reproducible from the source).
- For host installs, the installer MUST create symlinks from `<DOTFILES_DIR>/...` to the target paths so live edits in the repo propagate to the home directory.
- For devcontainer / Codespaces installs, the installer MUST force-copy config files into target dirs (`stomp_configs`) so that every container rebuild gets a fresh copy.
- For files with host/container variants (`claude-code/settings.json` vs. `settings.container.json`; `codex/config.toml` vs. `config.container.toml`), the `_deploy_variant_file` helper MUST pick the source by `is_devcontainer()`, symlink the host variant on hosts, and copy the container variant inside devcontainers.
  The container variant is copied (not symlinked) so the dotfiles repo need not be present at runtime.
- The installer MUST NOT touch `~/.gitconfig` (user identity); it MUST only prepend an `[include]` directive to `~/.config/git/config`.

### Idempotency and re-runnability

- Re-running `install.sh` with no arguments after a successful prior run MUST exit cleanly with no errors and no duplicate config.
- Backups from prior runs MUST NOT be deleted; each run creates a new timestamped backup directory only if it actually backs up something.
- The git `[include]` MUST be detected and not re-added on subsequent runs.

### Opt-out toggles

- `DOTFILES_NO_AI_TOOLS=1` MUST skip Claude Code, Codex CLI, ast-grep, difftastic installation and AI-tool config deployment.
- `DOTFILES_NO_ATUIN=1` MUST skip atuin shell history setup.
- `DOTFILES_NO_GIT_HOOKS=1` MUST skip global git hook deployment.
- `DOTFILES_NO_STATE_PERSISTENCE=1` MUST skip state-persistence tier detection and setup.
- `DOTFILES_NO_SSH_SIGNING=1` MUST skip SSH commit signing detection (no `ssh-add` or `~/.ssh/*.pub` access).
- `DOTFILES_OPINIONATED_ALIASES=1` MUST cause `grep` and `find` to be aliased to `rg` and `fd` in the deployed shell config.

### SSH commit signing

- When `DOTFILES_NO_SSH_SIGNING` is unset and `user.signingkey` is not already configured, the installer MUST attempt detection.
- On hosts, detection order is: (1) `ssh-add -L` preferring an `ssh-ed25519` key, (2) `~/.ssh/id_ed25519.pub`, (3) `~/.ssh/id_rsa.pub`.
  The file-key fallback supports fresh-install bootstrap before the agent is set up.
- Inside devcontainers, only the `ssh-add -L` agent-forwarding path MUST be used.
  The file-key fallback MUST be skipped because devcontainers MUST NOT mount `~/.ssh` from the host.
  The container relies on the ssh-agent socket forwarded from the host (made allow-listed under the host's Claude Code sandbox via `allowUnixSockets`).
- On success, the installer MUST set `user.signingkey` and `commit.gpgsign=true` globally and create `~/.config/git/allowed_signers`.
  Signing requires git >= 2.35 (for the `key::<literal>` parser); see `packages` spec.
- On failure (no key found), signing MUST stay disabled and the installer MUST NOT block.

## Scenarios

### Scenario: First-time install on a fresh devcontainer

GIVEN a fresh Codespace with no `~/.bashrc`, no `~/.gitconfig`, and no `~/.dotfiles-state/`
WHEN the user runs `./install.sh`
THEN the installer detects `Environment: codespaces`
AND backs up nothing (no pre-existing real files)
AND symlinks `~/.bashrc -> $DOTFILES_DIR/shell/.bashrc`
AND prepends `[include]` to a freshly created `~/.config/git/config`
AND deploys `~/.claude/`, `~/.codex/`, `~/.copilot/` from dotfiles
AND sets up state persistence in `/workspaces/.codespaces/.persistedshare/dotfiles-state/`
AND exits 0 with `Installation Complete`.

### Scenario: Re-run on an already-installed system

GIVEN a system where `./install.sh` has already run successfully
WHEN the user runs `./install.sh` again
THEN the installer skips creating duplicate `[include]` entries
AND replaces existing symlinks (no backup needed)
AND does NOT create a new `~/.dotfiles_backup_<timestamp>/` directory
AND exits 0.

### Scenario: Opt-in to unattended harness

GIVEN a host install
WHEN the user runs `./install.sh --with-unattended`
THEN the installer sets `DOTFILES_INSTALL_UNATTENDED=1`
AND deploys `~/.unattended/` (ralph.sh, dc-audit rubric, templates, unattended bootstrap scripts)
AND vendors `bootstrap/logging.sh` to `~/.unattended/lib/logging.sh`.

### Scenario: Workspace dotfiles auto-skip

GIVEN a self-edit devcontainer where the dotfiles repo IS the workspace
AND `DOTFILES_WORKSPACE=1` is set in `containerEnv`
AND VS Code's dotfiles mechanism invokes `~/.dotfiles/install.sh` (not the workspace clone)
WHEN that VS-Code-driven invocation runs
THEN the installer detects `SCRIPT_DIR != DOTFILES_DIR`
AND logs `Deferring install to postCreateCommand`
AND exits 0 without doing further work.

### Scenario: Missing SSH key, signing disabled

GIVEN a host with no SSH agent and no `~/.ssh/id_*.pub`
WHEN `./install.sh` runs without `DOTFILES_NO_SSH_SIGNING=1`
THEN the installer logs `No SSH key found -- commit signing disabled`
AND does NOT set `user.signingkey` or `commit.gpgsign`
AND continues to completion.

## Non-Behavior

- The installer does NOT install project-dependent tools (gh, docker, kubectl, mise, uv) -- these are configured-only.
- The installer does NOT modify `~/.gitconfig` (user identity is sacred).
- The installer does NOT install MCP servers.
- The installer does NOT delete `~/.dotfiles_backup_*` directories from prior runs.
- The installer does NOT bypass any opt-out toggle silently -- if `DOTFILES_NO_*=1` is set, it logs the skip explicitly.
- The installer does NOT support a `--dry-run` flag (out of scope; users who want a preview read this spec).
