# Tasks: Devcontainer Support

## Phase 1: Setup

- [X] T001 Create `.devcontainer/example/devcontainer.json` reference
       config with the recommended volume mount.
- [X] T002 [P] Add devcontainer / Codespaces detection cases to
       `tests/unit-tests.sh`.

## Phase 2: Foundational

- [X] T003 Implement `bootstrap/detect.sh::detect_state_tier` (pure;
       returns volume / codespaces / ephemeral).
- [X] T004 Implement `bootstrap/symlinks.sh::setup_state_persistence`
       (side-effecting; per-tier behavior).
- [X] T005 Implement `bootstrap/symlinks.sh::setup_volume_dir`
       (migrates real-dir contents to volume, then symlinks).
- [X] T006 Implement `bootstrap/symlinks.sh::_wire_tool_dir` (volume-
       back ~/.claude, ~/.codex, ~/.copilot when state available).

## Phase 3: User Story 1 - Codespaces auto-uses persistedshare (P1)

### Tests

- [X] T007 [P] [US1] Test in CI Codespaces simulator: assert
       STATE_TIER=codespaces, STATE_PATH ends with `.persistedshare/
       dotfiles-state`.
- [X] T008 [P] [US1] Test: write Claude credential, simulate rebuild,
       assert credential persists.

### Implementation

- [X] T009 [US1] In `setup_state_persistence`, handle `codespaces`
       case: mkdir, symlink, chmod 700.

## Phase 4: User Story 2 - Local volume mount (P1)

### Tests

- [X] T010 [P] [US2] Test: pre-mount volume; assert STATE_TIER=volume.
- [X] T011 [P] [US2] Test: write sentinel; rebuild (simulate); assert
       sentinel persists.

### Implementation

- [X] T012 [US2] In `detect_state_tier`, prefer volume tier: real
       directory at ~/.dotfiles-state, not a symlink.

## Phase 5: User Story 3 - Ephemeral fallback (P2)

### Tests

- [X] T013 [P] [US3] Test: no volume, not Codespaces; assert
       STATE_TIER=ephemeral and recommended `mounts` line is logged.

### Implementation

- [X] T014 [US3] In `setup_state_persistence`, ephemeral case:
       mkdir, chmod 700, log mount snippet.

## Phase 6: User Story 4 - Native AI tool install (P1)

### Tests

- [X] T015 [P] [US4] CI test in Node-less container: claude and codex
       binaries install successfully.
- [X] T016 [P] [US4] Test: install completes in <10s overhead vs host.

### Implementation

- [X] T017 [US4] In `bootstrap/packages.sh`, install Claude Code via
       its native install script (no npm).
- [X] T018 [US4] Same for Codex CLI.

## Phase 6a: Variant deployment and egress pivot

### Tests

- [X] T018a [P] Test: in a devcontainer, `~/.claude/settings.json`
       and `~/.codex/config.toml` are regular files (copies), not
       symlinks; deleting `/workspaces/.dotfiles` does not break Claude
       or Codex launch.
- [X] T018b [P] Test: `bootstrap/devcontainer-egress.sh` MUST NOT
       exist in the working tree (`fd devcontainer-egress.sh` returns
       nothing).
- [X] T018c [P] Test: `is_minimal_install` and `is_devcontainer`
       return the same value across every detection case in
       `tests/unit-tests.sh`.

### Implementation

- [X] T018d Confirm `is_minimal_install` body is just
       `is_devcontainer`; both stay exported.
- [X] T018e Use `_deploy_variant_file` in `_setup_claude_code` and
       `_setup_codex` so the container variants are copied, not
       symlinked.
- [X] T018f Remove `bootstrap/devcontainer-egress.sh` and the
       `DOTFILES_DEVCONTAINER_EGRESS` / `DOTFILES_EGRESS_EXTRA_HOSTS`
       env-var handling from `install.sh`. The attended-profile
       defense is now dc-audit spec-linting under `make lint`.

## Phase 7: Polish

- [X] T019 Document state-persistence section in README.md.
- [X] T020 Run `make lint`; expect 0 warnings.
- [X] T021 Run `make test-integration`; expect green on devcontainer
       and Codespaces matrix cells.

## Dependencies

Phase 1 -> Phase 2 -> Phases 3-6 (parallel) -> Phase 7.

## Implementation Strategy

MVP is User Stories 1 + 4 (Codespaces + native install). Story 2
(volume) is the local-dev story. Story 3 (ephemeral) is the
graceful-degradation safety net.
