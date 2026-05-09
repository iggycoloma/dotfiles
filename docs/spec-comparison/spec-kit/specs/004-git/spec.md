# Feature Specification: Git Configuration

**Branch**: `004-git` | **Date**: 2026-04-01 | **Status**: Implemented

## User Scenarios & Testing

### User Story 1 - Identity preserved, defaults included (Priority: P1)

A developer's `~/.gitconfig` (with their identity) is never touched, but
the dotfiles' delta config / aliases / hooks all activate.

**Independent Test**: Pre-seed `~/.gitconfig` with a name+email, run
installer, assert `git config user.name` returns the seeded name AND
`git config alias.s` returns `status -sb`.

**Acceptance Scenarios**:
```
GIVEN ~/.gitconfig contains [user] name = Alice, email = alice@example.com
  AND no ~/.config/git/config exists
WHEN ./install.sh runs
THEN ~/.gitconfig is byte-for-byte unchanged
  AND ~/.config/git/config is a real file (not a symlink)
  AND its first lines are [include] / path = <DOTFILES_DIR>/git/.gitconfig
  AND `git config user.name` returns Alice
  AND `git config alias.s` returns "status -sb" (from the included file)
```

### User Story 2 - Personal override wins over dotfiles default (Priority: P1)

A developer can override any dotfiles default via `git config --global`
without dirtying the repo.

**Independent Test**: Run `git config --global pull.rebase true`, then
`git config pull.rebase`, assert `true` (default in dotfiles is `false`).

**Acceptance Scenarios**:
```
GIVEN dotfiles config sets pull.rebase = false
WHEN the user runs `git config --global pull.rebase true`
THEN the write goes to ~/.config/git/config after the [include] section
  AND `git config pull.rebase` returns true
```

### User Story 3 - Migration from legacy whole-file symlink (Priority: P2)

Older installs symlinked `~/.config/git/config` directly to the dotfiles
gitconfig. New installs convert this to the `[include]` model
automatically.

**Independent Test**: Pre-seed `~/.config/git/config` as a symlink to the
dotfiles gitconfig, run installer, assert it's now a real file with
`[include]`.

**Acceptance Scenarios**:
```
GIVEN ~/.config/git/config is a symlink to <DOTFILES_DIR>/git/.gitconfig
WHEN ./install.sh runs
THEN the symlink is removed
  AND a real file is created at ~/.config/git/config with [include] prepended
  AND the installer logs "Migrating git config from symlink to [include] pattern"
```

### Edge Cases

- **`~/.config/git/config` already has `[include]`**: skip duplicate add,
  log "already includes dotfiles settings".
- **`~/.config/git/config` exists but is empty**: prepend `[include]`
  cleanly.
- **No git installed**: shell config still deploys; git capability is
  silently inert until git appears.

## Requirements

### Functional Requirements

- **FR-001** Installer MUST never modify `~/.gitconfig`.
- **FR-002** Installer MUST ensure `~/.config/git/config` is a real file
  (migrate from symlink if needed).
- **FR-003** Installer MUST prepend `[include]\n\tpath = <DOTFILES_DIR>/git/.gitconfig`
  to `~/.config/git/config` if not already present.
- **FR-004** Installer MUST detect existing `[include]` via `grep -qF` and
  skip duplicate.
- **FR-005** Dotfiles `git/.gitconfig` MUST set `core.pager = delta` and
  delta config (theme, line numbers).
- **FR-006** Dotfiles `git/.gitconfig` MUST define >= 44 aliases.
- **FR-007** Dotfiles `git/.gitconfig` MUST set `gpg.format = ssh` and
  `gpg.ssh.allowedSignersFile`.
- **FR-008** Dotfiles `git/.gitconfig` MUST NOT set `commit.gpgsign`
  (per-host decision).
- **FR-009** Dotfiles `git/.gitconfig` MUST set `[push]` `default = current`
  and `autoSetupRemote = true`; `[pull] rebase = false`; `[fetch] prune =
  true`; `[rebase] autoStash = true`; `[init] defaultBranch = main`.

### Key Entities

- **Git config layer**: `identity (~/.gitconfig) | personal-override (~/.config/git/config) | dotfiles-defaults (git/.gitconfig)`.
  Layering order matters; later wins.

## Success Criteria

- **SC-001** Identity preservation: 100% of test runs leave `~/.gitconfig`
  unchanged.
- **SC-002** Re-run does not duplicate `[include]` in any test run.
- **SC-003** Personal override via `git config --global` always wins
  (CI test).
- **SC-004** All 44 aliases resolve via `git <alias>` after install.

## Assumptions

- The user has a non-empty `~/.gitconfig` (or accepts the empty-identity
  warning).
- `~/.config/git/config` is the user's personal override layer; we do not
  manage it for them beyond the `[include]`.
