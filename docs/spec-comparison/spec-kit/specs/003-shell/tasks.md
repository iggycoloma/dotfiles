# Tasks: Shell Configuration

## Phase 1: Setup

- [X] T001 Create `shell/.bashrc`, `shell/.bash_profile`, `shell/.zshrc`,
       `shell/.zprofile` with shared sourcing skeleton.
- [X] T002 [P] Add `tests/test-functions.sh` skeleton.

## Phase 2: Foundational

- [X] T003 Create `shell/aliases.sh` with 80+ aliases grouped (git, docker,
       k8s, python, navigation, modern-tool replacements).
- [X] T004 [P] Create `shell/exports.sh` with XDG vars, EDITOR chain, FZF
       defaults, BAT_THEME, CLAUDE_CONFIG_DIR.
- [X] T005 [P] Create `shell/functions.sh` with 25+ functions (mkcd,
       extract, killport, gcof, glf, dotfiles-doctor, smart cat).
- [X] T006 [P] Create `shell/completion.sh` with init for fzf, zoxide,
       atuin, direnv, carapace.

## Phase 3: User Story 1 - Fast zsh startup (Priority: P1)

### Tests

- [X] T007 [P] [US1] CI captures `time zsh -i -c exit` for cold and warm
       cache; assert warm < 200ms.
- [X] T008 [P] [US1] Test: `ZSH_PROFILE=1 zsh -i -c exit` emits zprof
       output mentioning `precmd_functions`.

### Implementation

- [X] T009 [US1] `~/.zshrc`: cache compinit dump (`zcompdump`); rebuild
       only if older than 24h.
- [X] T010 [US1] `~/.zshrc`: defer zoxide and direnv init via `precmd`
       hook (run once on first prompt).
- [X] T011 [US1] `~/.zshrc`: gate `zprof` on `ZSH_PROFILE=1`.

## Phase 4: User Story 2 - 80+ aliases (Priority: P1)

### Tests

- [X] T012 [P] [US2] Test: `alias | wc -l` returns >= 80 in a fresh shell.
- [X] T013 [P] [US2] Test: `type grep` returns system grep when
       `DOTFILES_OPINIONATED_ALIASES` is unset.
- [X] T014 [P] [US2] Test: `type grep` returns `alias grep='rg'` when
       `DOTFILES_OPINIONATED_ALIASES=1`.

### Implementation

- [X] T015 [US2] Populate `aliases.sh` with the 80+ alias set.
- [X] T016 [US2] Wrap grep/find aliases in
       `[[ "${DOTFILES_OPINIONATED_ALIASES:-}" == "1" ]]` guard.

## Phase 5: User Story 3 - Local overrides (Priority: P2)

### Tests

- [X] T017 [P] [US3] Test: write `~/.aliases.local` with a sentinel alias;
       restart shell; assert the alias is defined.

### Implementation

- [X] T018 [US3] In `~/.bashrc` and `~/.zshrc`, source each
       `~/.{bashrc,zshrc,exports,aliases,functions}.local` if present.

## Phase 6: Polish

- [X] T019 Verify all functions handle `--help` consistently.
- [X] T020 Run `make lint`; expect 0 warnings.
- [X] T021 Run `make test-functions`; expect green.

## Dependencies

Phase 1 -> Phase 2 (parallel possible across alias/function/export/completion files) -> Phases 3-5 (mostly parallel) -> Phase 6.

## Implementation Strategy

MVP is User Story 2 (aliases work). Layer Story 1 (perf) and Story 3
(overrides) after.
