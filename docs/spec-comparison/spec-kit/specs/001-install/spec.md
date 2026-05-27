# Feature Specification: Install

**Branch**: `001-install`
**Date**: 2026-04-01
**Status**: Implemented (canonical -- this spec describes the as-built behavior)

## User Scenarios & Testing

### User Story 1 - Fresh devcontainer install (Priority: P1)

A developer opens a Codespace (or rebuilds a local devcontainer) and wants
their full developer environment ready when the terminal first appears.

**Why this priority**: This is the dominant use case -- every other story is
either an opt-in or a re-run of P1.

**Independent Test**: Spin up a fresh container image, run `./install.sh`,
and assert: shell rc symlinks exist, core tools resolve on PATH, git
`[include]` is in place, AI tool config is deployed, `dotfiles-doctor`
reports green.

**Acceptance Scenarios**:

```
GIVEN a fresh container with no ~/.bashrc, no ~/.gitconfig, no ~/.dotfiles-state
WHEN the user runs ./install.sh
THEN ~/.bashrc -> $DOTFILES_DIR/shell/.bashrc symlink is created
  AND ~/.config/git/config contains [include] of the dotfiles gitconfig
  AND ~/.claude/, ~/.codex/, ~/.copilot/ are populated from dotfiles
  AND state persistence tier is detected and set up
  AND the installer exits 0 with "Installation Complete"
```

### User Story 2 - Re-run is a no-op (Priority: P1)

A developer pulls a new dotfiles version and re-runs the installer to pick
up changes without breaking anything.

**Why this priority**: Idempotency is foundational; without it the install is
not safe-to-rerun and users hesitate to update.

**Independent Test**: Run `./install.sh` twice in succession; assert second
run completes successfully, no duplicate `[include]` is added, and no new
backup directory is created on the second run.

**Acceptance Scenarios**:

```
GIVEN ./install.sh has already run once successfully
WHEN the user runs ./install.sh again
THEN no duplicate [include] entry is appended to ~/.config/git/config
  AND no new ~/.dotfiles_backup_<timestamp> directory is created
  AND the installer exits 0
```

### User Story 3 - Opt-in to unattended harness (Priority: P2)

A developer who runs Claude Code autonomously wants the unattended harness
deployed.

**Why this priority**: P2 because the harness is a separate product;
mainstream users do not need it but the opt-in path must be clean.

**Independent Test**: Run `./install.sh --with-unattended` on a fresh host;
assert `~/.unattended/scripts/ralph.sh` is executable and
`~/.unattended/devcontainer-rubric.json` exists.

**Acceptance Scenarios**:

```
GIVEN a host without DOTFILES_INSTALL_UNATTENDED set
WHEN the user runs ./install.sh --with-unattended
THEN DOTFILES_INSTALL_UNATTENDED=1 is exported
  AND ~/.unattended/scripts/ralph.sh is deployed and executable
  AND ~/.unattended/lib/logging.sh is vendored from bootstrap/logging.sh
  AND the installer logs "Unattended harness deployed to ~/.unattended/"
```

### User Story 4 - SSH signing auto-detection (Priority: P2)

A developer wants commit signing to work in devcontainers without copying
private keys around.

**Why this priority**: P2 because signing is a quality-of-life feature, but
brokenness here causes silent commit-signing failures that frustrate users.

**Independent Test**: With `ssh-add -L` exposing an ed25519 key, run
`./install.sh`; assert `git config user.signingkey` returns the key and
`commit.gpgsign` is true.

**Acceptance Scenarios**:

```
GIVEN ssh-add -L returns an ssh-ed25519 key
  AND DOTFILES_NO_SSH_SIGNING is unset
  AND user.signingkey is not yet configured
WHEN ./install.sh runs
THEN user.signingkey is set to "key::<the ed25519 key>"
  AND commit.gpgsign is true
  AND ~/.config/git/allowed_signers contains the email + key
```

### Edge Cases

- **Self-edit devcontainer**: When `DOTFILES_WORKSPACE=1` is set and VS
  Code's dotfiles mechanism invokes `~/.dotfiles/install.sh` from outside
  the workspace, the installer detects `SCRIPT_DIR != DOTFILES_DIR` and
  defers to `postCreateCommand`. Exits 0 cleanly.
- **No SSH key available**: Install completes; signing stays disabled with
  a warning. No commit-time errors.
- **Codespaces persisted-share unwritable**: Falls back to ephemeral tier
  with a warning; install still completes.
- **Pre-existing `~/.gitconfig`**: The installer never touches it. Only
  `~/.config/git/config` is modified.
- **Unknown CLI flag**: Tolerated (silent skip) so older CI callers don't
  break.

## Requirements

### Functional Requirements

- **FR-001** The installer MUST run with `bash` and MUST set `set -u` early.
- **FR-002** The installer MUST accept `--with-unattended`, `--without-unattended`,
  `-h`, `--help` and tolerate unknown args.
- **FR-003** The installer MUST detect environment as `codespaces`,
  `devcontainer`, `remote`, or `local`.
- **FR-004** The installer MUST detect OS as `macos`, `debian`, `alpine`,
  `linux`, or `unknown`.
- **FR-005** The installer MUST detect package manager as `brew`, `apt`,
  `apk`, or `none`.
- **FR-006** Pre-existing real files at target paths MUST be backed up to
  `~/.dotfiles_backup_<timestamp>/` before replacement.
- **FR-007** Pre-existing symlinks at target paths MUST be replaced without
  backup.
- **FR-008** On hosts, the installer MUST symlink files; on devcontainers,
  it MUST force-copy (stomp) so containers always reflect the current
  dotfiles.
- **FR-009** The installer MUST never modify `~/.gitconfig`.
- **FR-010** The installer MUST be idempotent: re-running with no args after
  success exits 0, creates no duplicate config, no new backup dir.
- **FR-011** The installer MUST honor every `DOTFILES_NO_*` opt-out toggle
  on every run.
- **FR-012** SSH signing detection MUST be skipped entirely when
  `DOTFILES_NO_SSH_SIGNING=1` is set.
- **FR-013** When SSH signing detection runs and finds no key, signing MUST
  stay disabled (no error, warn only).
- **FR-014** On hosts, signing-key detection order MUST be (1) `ssh-add -L`
  preferring `ssh-ed25519`, (2) `~/.ssh/id_ed25519.pub`, (3)
  `~/.ssh/id_rsa.pub`. Inside devcontainers, only the `ssh-add -L`
  path MUST be used; the file-key fallback MUST be skipped because
  devcontainers MUST NOT mount `~/.ssh` from the host. The container
  relies on the ssh-agent socket forwarded from the host (allow-listed
  under the host's Claude Code sandbox via `allowUnixSockets`).
- **FR-015** Variant files (`claude-code/settings.json` vs.
  `settings.container.json`; `codex/config.toml` vs.
  `config.container.toml`) MUST be deployed via the
  `_deploy_variant_file` helper: symlink the host variant on hosts,
  copy the container variant inside devcontainers.

### Key Entities

- **Environment**: tagged enum `codespaces | devcontainer | remote | local`.
- **OS**: tagged enum `macos | debian | alpine | linux | unknown`.
- **Backup directory**: timestamped path
  `~/.dotfiles_backup_YYYYMMDD_HHMMSS/`, created lazily.
- **State persistence tier**: tagged enum `volume | codespaces | ephemeral`
  (see `devcontainer-support` spec for tier semantics).

## Success Criteria

### Measurable Outcomes

- **SC-001** Cold install on a fresh Codespace completes in under 90 seconds
  (network-bound on tool downloads).
- **SC-002** Re-install on an already-installed system completes in under
  20 seconds.
- **SC-003** `dotfiles-doctor` reports 0 failures after install on every
  CI matrix cell.
- **SC-004** Install survives every `DOTFILES_NO_*` toggle in isolation
  (4 toggles -> 4 alternate-path CI cells, all green).
- **SC-005** Self-edit devcontainer auto-skip path (`DOTFILES_WORKSPACE=1`
  with mismatched script dir) exits 0 in under 1 second.

## Assumptions

- The user has bash available (POSIX bash; macOS bash 3.2 is the floor).
- The user has either `apt`, `apk`, `brew`, or knows the install will be
  no-op'd to "tools missing".
- The host's git identity is either present (`~/.gitconfig` from VS Code
  copy or Codespaces auto-config) or the user accepts the warning.
- Network access is available for GitHub-release downloads on first install.
- `~/.dotfiles_backup_*` directories are not deleted by other tooling
  before the user has a chance to inspect them.
