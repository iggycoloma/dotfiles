# Tasks: Diagnostics

## Phase 1: Setup

- [X] T001 Stub `dotfiles-doctor` function in `shell/functions.sh`.
- [X] T002 [P] Stub log functions in `bootstrap/logging.sh`.

## Phase 2: Foundational

- [X] T003 Implement color detection helper (`tput colors`, fallback to plain text when not a TTY).
- [X] T004 [P] Implement `_doctor_check <name> <predicate>` helper that emits `ok|warn|fail` formatted output.

## Phase 3: User Story 1 - Doctor reports health (P1)

### Tests
- [X] T005 [P] [US1] Test: post-install, dotfiles-doctor reports `27 passed, 0 warnings, 0 failed`.
- [X] T006 [P] [US1] Test: remove `bat`, run doctor, assert `fail bat (not found)` and non-zero exit.
- [X] T007 [P] [US1] Test: doctor performs no writes (verified by fs snapshot diff).

### Implementation
- [X] T008 [US1] Symlinks section: enumerate expected symlinks; check each.
- [X] T009 [US1] Core Tools section: enumerate core tools; report version on `ok`, `not found` on `fail`.
- [X] T010 [US1] Git Configuration section: check user.name, user.email, user.signingkey, [include] presence.
- [X] T011 [US1] Summary line: count passed/warnings/failed; exit non-zero on any failed.

## Phase 4: User Story 2 - Shell startup profiling (P2)

### Tests
- [X] T012 [P] [US2] Test: `ZSH_PROFILE=1 zsh -i -c exit` emits output containing `precmd_functions`.
- [X] T013 [P] [US2] Test: warm-cache startup < 200ms.

### Implementation
- [X] T014 [US2] In `~/.zshrc`, gate `zmodload zsh/zprof` on `${ZSH_PROFILE:-}`.
- [X] T015 [US2] Add `zprof` call to `zshexit_functions` when gate is on.
- [X] T016 [US2] Wire CI to log `time zsh -i -c exit` per matrix cell.

## Phase 5: User Story 3 - Install logging readable in CI (P2)

### Tests
- [X] T017 [P] [US3] Test: capture install output in non-TTY mode; grep for ANSI sequences -> none found.
- [X] T018 [P] [US3] Test: log_warn / log_error visually distinct in plain text.

### Implementation
- [X] T019 [US3] Each log function checks `[ -t 1 ]` before emitting ANSI; falls back to plain prefix (`[WARN]`, `[ERROR]`).
- [X] T020 [US3] log_section emits a recognizable separator (e.g.
  `==> Section Name`) in both modes.

## Phase 5a: Shared detect/logging libs in validate-dotfiles

### Tests

- [X] T020a Test: `tests/validate-dotfiles.sh` sources `bootstrap/detect.sh` and `bootstrap/logging.sh`; grep the file for inline redefinitions of `log_info` / `is_devcontainer` and assert none are present.
- [X] T020b Test: inside a devcontainer (or with `/.dockerenv` present), `validate-dotfiles.sh` correctly reports `Environment: devcontainer`; the previous local copy missed this because it did not check `/.dockerenv`.

### Implementation

- [X] T020c Refactor `tests/validate-dotfiles.sh` to `source "$DOTFILES_DIR/bootstrap/detect.sh"` and `source "$DOTFILES_DIR/bootstrap/logging.sh"`.
  Drop the in-file copies of `log_*` / detection helpers.

## Phase 6: Polish

- [X] T021 Add actionable next-step messages on common install failures (missing apt-get update, no SSH key, etc.).
- [X] T022 Run `make lint`; expect 0 warnings.
- [X] T023 Run `tests/test-functions.sh`; expect green.

## Dependencies

Phase 1 -> Phase 2 -> Phases 3-5 (parallel) -> Phase 6.

## Implementation Strategy

MVP is User Story 1 (doctor).
Story 2 (profiling) and Story 3 (logging) are quality-of-life follow-ups.
