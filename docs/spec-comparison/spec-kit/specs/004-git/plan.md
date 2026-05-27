# Implementation Plan: Git Configuration

**Branch**: `004-git` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)

## Summary

Three-file git config model: `~/.gitconfig` (identity, untouched),
`~/.config/git/config` (XDG real file with `[include]`),
`<DOTFILES_DIR>/git/.gitconfig` (defaults). Installer prepends `[include]`
idempotently and migrates legacy whole-file symlinks. Delta integration,
44 aliases, SSH commit signing.

## Technical Context

| Field             | Value                                          |
|-------------------|------------------------------------------------|
| Language/Version  | Bash; git >= 2.35 (for `[push] autoSetupRemote` and SSH commit signing's `key::<literal>` parser; the installer opportunistically upgrades Ubuntu via `ppa:git-core/ppa` -- see spec 002-packages) |
| Dependencies      | git, delta (for diffs), ssh (for signing)      |
| Storage           | `~/.gitconfig`, `~/.config/git/config`         |
| Testing           | `tests/test-install.sh` (post-install assertions) |
| Target Platform   | All                                            |
| Project Type      | Single Project                                 |
| Performance Goals | n/a (config deploy is sub-second)              |
| Constraints       | Never modify identity file                     |
| Scale/Scope       | 44 aliases, 1 include directive                |

## Constitution Check

| Article                            | Status | Notes                                                      |
|------------------------------------|--------|------------------------------------------------------------|
| I. Developer-Specific              | PASS   | Universal git QoL.                                         |
| II. Defense-in-Depth Security      | PASS   | SSH signing keyed off public key only; identity untouched. |
| III. Cross-Platform Parity         | PASS   | All matrix cells.                                          |
| IV. Idempotent and Reversible      | PASS   | `[include]` detection prevents duplication; symlink backup. |
| V. Opt-In for High-Risk Surface    | PASS   | Signing auto-detect is opt-out via `DOTFILES_NO_SSH_SIGNING`. |

## Project Structure

```
git/
|-- .gitconfig
|-- .gitignore_global
|-- .gitmessage
+-- hooks/                    (delegated to spec 005-git-hooks)
bootstrap/
+-- symlinks.sh               (_ensure_git_include lives here)
```

### Structure Decision

Single Project. Git config is one file with sections; aliases inline. Hook
deployment is its own capability (`005-git-hooks`).

## Complexity Tracking

(empty)
