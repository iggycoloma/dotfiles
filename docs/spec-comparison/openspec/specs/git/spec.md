# git

## Overview

Git configuration deployed via a three-file model that keeps user identity
separate from repo settings. Provides delta-rendered diffs, 44 aliases, SSH
commit signing, and an XDG-compliant config that supports `git config --global`
writes without dirtying the dotfiles repo.

## Requirements

### Three-file config model

- `~/.gitconfig` MUST hold user identity only (`user.name`, `user.email`,
  `user.signingkey`). The installer MUST NOT touch this file.
- `~/.config/git/config` MUST be a real file (not a symlink) so `git config
  --global` writes succeed safely.
- `~/.config/git/config` MUST contain an `[include]` directive whose `path`
  points at `<DOTFILES_DIR>/git/.gitconfig`.
- The dotfiles `git/.gitconfig` MUST hold all shared settings: delta config,
  aliases, hook path, merge/diff/push/fetch/rebase defaults.

### Include semantics

- The installer MUST detect an existing `[include]` for the dotfiles
  gitconfig and MUST NOT add a duplicate on re-run.
- The installer MUST migrate from a legacy whole-file symlink (older
  installs) by removing the symlink and creating a real file with
  `[include]` prepended.
- Personal settings written via `git config --global` MUST go to
  `~/.config/git/config` (the XDG file) and MUST override the included
  defaults.

### Aliases

- The dotfiles `git/.gitconfig` MUST define at least 44 aliases covering
  every common operation: status (`s`), commit (`c`, `cm`, `ca`, `can`),
  checkout (`co`, `cob`), branch (`b`, `ba`, `bd`, `bD`), push/pull (`p`,
  `pf`, `pl`, `plr`), diff (`d`, `ds`, `dc`), log (`l`, `la`, `lg`, `lga`),
  stash (`st`, `stp`, `stl`, `sta`), reset (`unstage`, `undo`, `rh`, `rhh`),
  rebase (`r`, `ri`, `rc`, `ra`), and discovery (`aliases`, `branches`,
  `remotes`, `tags`, `last`, `contributors`).

### Delta integration

- `git/.gitconfig` MUST set `core.pager = delta` and
  `interactive.diffFilter = delta --color-only`.
- The `[delta]` section MUST set `navigate=true`, `light=false`,
  `side-by-side=false`, `line-numbers=true`,
  `syntax-theme=OneHalfDark`.

### SSH commit signing

- `git/.gitconfig` MUST set `gpg.format = ssh` and
  `gpg.ssh.allowedSignersFile = ~/.config/git/allowed_signers`.
- The installer MUST NOT set `commit.gpgsign` in the dotfiles config; that
  flag is set per-host by `install.sh` only when an SSH key is detected.
- The `allowed_signers` file MUST be created at
  `~/.config/git/allowed_signers` with the user's email and public key.

### Defaults

- `[push]` MUST set `default = current` and `autoSetupRemote = true`.
- `[pull]` MUST set `rebase = false` (merge by default).
- `[fetch]` MUST set `prune = true`.
- `[rebase]` MUST set `autoStash = true`.
- `[init]` MUST set `defaultBranch = main`.

## Scenarios

### Scenario: Fresh install adds [include] without touching identity

GIVEN a host with `~/.gitconfig` containing `[user]\n\tname = Alice\n\temail = alice@example.com`
AND no `~/.config/git/config`
WHEN `./install.sh` runs
THEN `~/.gitconfig` is unchanged
AND `~/.config/git/config` is created with `[include]\n\tpath = <DOTFILES_DIR>/git/.gitconfig` at the top
AND `git config user.name` returns `Alice`
AND `git config alias.s` returns `status -sb` (from the included config).

### Scenario: Personal override wins over dotfiles default

GIVEN dotfiles config sets `pull.rebase = false`
WHEN the user runs `git config --global pull.rebase true`
THEN the write goes to `~/.config/git/config` after the `[include]`
AND `git config pull.rebase` returns `true`
AND the dotfiles default is overridden.

### Scenario: Idempotent re-run does not duplicate include

GIVEN `~/.config/git/config` already contains the dotfiles `[include]`
WHEN `./install.sh` runs again
THEN the installer detects the existing include
AND skips appending a duplicate
AND logs `Git config already includes dotfiles settings`.

### Scenario: Migration from legacy whole-file symlink

GIVEN `~/.config/git/config` is a symlink to an old version of `git/.gitconfig`
WHEN `./install.sh` runs
THEN the installer removes the symlink
AND creates a real file at `~/.config/git/config` with `[include]` prepended
AND logs `Migrating git config from symlink to [include] pattern`.

## Non-Behavior

- The installer does NOT modify `~/.gitconfig` for any reason.
- The installer does NOT set `commit.gpgsign` in the dotfiles config.
- The dotfiles config does NOT use GPG signing -- SSH only.
- The dotfiles config does NOT set `user.email` or `user.name` (those
  belong to identity).
- The dotfiles config does NOT enable submodule recursion by default
  (intentional; explicit `git submodule update --init --recursive` only).
