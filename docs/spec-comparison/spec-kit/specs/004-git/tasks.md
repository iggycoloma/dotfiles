# Tasks: Git Configuration

## Phase 1: Setup

- [X] T001 Create `git/.gitconfig` skeleton with `[core]`, `[delta]`,
       `[merge]`, `[diff]`, `[pull]`, `[push]`, `[fetch]`, `[rebase]`,
       `[init]`, `[commit]`, `[gpg]`, `[gpg "ssh"]`, `[color "*"]`,
       `[alias]` sections.
- [X] T002 [P] Create `git/.gitignore_global`, `git/.gitmessage`.

## Phase 2: Foundational

- [X] T003 Implement `bootstrap/symlinks.sh::_ensure_git_include`:
       prepend `[include]` if not present, migrate from symlink if found.

## Phase 3: User Story 1 - Identity preserved (Priority: P1)

### Tests for User Story 1

- [X] T004 [P] [US1] Test: pre-seed `~/.gitconfig` with name+email, run
       installer, assert file is byte-identical after.
- [X] T005 [P] [US1] Test: assert `~/.config/git/config` is a real file
       (not symlink) after install.
- [X] T006 [P] [US1] Test: `git config alias.s` returns "status -sb"
       (the included config takes effect).

### Implementation for User Story 1

- [X] T007 [US1] Wire `_ensure_git_include` into `create_symlinks`.
- [X] T008 [US1] Symlink `~/.gitignore_global` and `~/.gitmessage` from
       dotfiles.
- [X] T009 [US1] Populate `git/.gitconfig` with delta config, defaults
       (push/pull/fetch/rebase/init), and 44 aliases.

## Phase 4: User Story 2 - Personal override wins (Priority: P1)

### Tests for User Story 2

- [X] T010 [P] [US2] Test: run `git config --global pull.rebase true`,
       then `git config pull.rebase`, assert `true`.
- [X] T011 [P] [US2] Test: `~/.config/git/config` ends up containing
       both `[include]` and the `[pull] rebase = true` override.

### Implementation for User Story 2

- [X] T012 [US2] No code change needed -- `[include]` first means
       writes to `~/.config/git/config` after the include override the
       included defaults, which is git's documented layering.

## Phase 5: User Story 3 - Migration from legacy symlink (Priority: P2)

### Tests for User Story 3

- [X] T013 [P] [US3] Test: pre-seed `~/.config/git/config` as symlink to
       `<DOTFILES_DIR>/git/.gitconfig`; run installer; assert it's now a
       real file with `[include]`.

### Implementation for User Story 3

- [X] T014 [US3] In `_ensure_git_include`, detect `[[ -L "$xdg_config" ]]`
       and `rm -f` it before prepending the include.

## Phase 6: Polish

- [X] T015 SSH signing setup logic (in 001-install Phase 6) consumes
       `gpg.format = ssh` from this config; cross-reference noted.
- [X] T016 Run `make lint`; expect 0 warnings.
- [X] T017 Run integration tests; expect green.

## Dependencies

Phase 1 -> Phase 2 -> Phases 3-5 (parallel possible) -> Phase 6.

## Implementation Strategy

MVP is User Story 1 (identity preserved + dotfiles defaults active).
Stories 2 and 3 fall out from the `[include]` design.
