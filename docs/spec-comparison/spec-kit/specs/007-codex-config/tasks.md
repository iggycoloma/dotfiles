# Tasks: Codex CLI Configuration

## Phase 1: Setup

- [X] T001 Create `codex/AGENTS.md` skeleton.
- [X] T002 [P] Create `codex/hooks.json` skeleton.
- [X] T003 [P] Create `codex/hooks/notify.sh` skeleton.
- [X] T004 [P] Create `codex/skills/claude-parity/` directory.

## Phase 2: Foundational

- [X] T005 Implement `bootstrap/symlinks.sh::_setup_codex` deploying
       AGENTS.md, hooks.json, hooks/, skills/.
- [X] T006 Implement `_setup_codex_notify` for config.toml (seed +
       string-to-array migration).
- [X] T007 Implement legacy whole-directory symlink migration.

## Phase 3: User Story 1 - Claude-parity workflows (Priority: P1)

### Tests

- [X] T008 [P] [US1] Test: invoke commit intent; assert claude-parity
       skill resolves and proposes conv-commit message.

### Implementation

- [X] T009 [US1] Author `skills/claude-parity/context-prime.md`,
       `commit.md`, `pr-create.md`, `review-pr.md`, `debug.md`,
       `test.md`, `dependencies.md`, `security-audit.md`,
       `feature-spec.md`, `pipeline.md`.
- [X] T010 [US1] In `pipeline.md`, encode the 4-stage flow with
       explicit user-checkpoint instructions.

## Phase 4: User Story 2 - Idle Pushover (Priority: P2)

### Tests

- [X] T011 [P] [US2] Test: notify.sh with PUSHOVER_TOKEN set hits the
       Pushover API.
- [X] T012 [P] [US2] Test: without env vars, notify.sh exits 0
       silently.

### Implementation

- [X] T013 [US2] Implement `notify.sh` (curl Pushover API, env-var
       gated).
- [X] T014 [US2] Wire notify hook in config.toml during install (handled
       by `_setup_codex_notify` from T006).

## Phase 5: User Story 3 - Local config.toml preserved (Priority: P2)

### Tests

- [X] T015 [P] [US3] Test: pre-seed `~/.codex/config.toml` with custom
       content on a host; run installer; assert byte-identical after.

### Implementation

- [X] T016 [US3] In `_setup_codex`, use `_deploy_variant_file` with
       `preserve_existing=1` so the host variant is symlinked on first
       install but a user-edited real file is preserved on re-install.
       Devcontainers always re-stomp the container variant.

## Phase 5a: User Story 4 - Host vs container sandbox mode (Priority: P1)

### Tests

- [X] T016a [P] [US4] Test: on a host, `~/.codex/config.toml` is a
       symlink to `codex/config.toml` and contains
       `sandbox_mode = "workspace-write"`.
- [X] T016b [P] [US4] Test: inside a devcontainer, `~/.codex/config.toml`
       is a regular file (copy) and contains
       `sandbox_mode = "danger-full-access"`. The dotfiles repo can be
       absent at runtime without breaking Codex.

### Implementation

- [X] T016c [US4] Author `codex/config.container.toml` mirroring the
       host `config.toml` but with `sandbox_mode = "danger-full-access"`.
- [X] T016d [US4] In `_setup_codex`, call
       `_deploy_variant_file "$DOTFILES_DIR/codex" config.toml config.container.toml "$HOME/.codex/config.toml" 1`.

## Phase 6: Polish

- [X] T017 Add shell aliases `cx` (codex), `cxe` (codex exec), `cxr`
       (codex review --uncommitted) to `shell/aliases.sh`.
- [X] T018 Run `make lint`; expect 0 warnings.
- [X] T019 Run `tests/test-consistency.sh`; expect deny-list parity
       across CLAUDE.md, AGENTS.md, copilot-instructions.md.

## Dependencies

Phase 1 -> Phase 2 -> Phases 3-5 (parallel possible) -> Phase 6.

## Implementation Strategy

MVP is User Story 1 (skills work). Stories 2 and 3 layer on after.
