# Tasks: Copilot CLI Configuration

## Phase 1: Setup

- [X] T001 Create `copilot/copilot-instructions.md` skeleton.
- [X] T002 [P] Create `copilot/hooks.json`.

## Phase 2: Foundational

- [X] T003 Implement `bootstrap/symlinks.sh::_setup_copilot` deploying both files.
- [X] T004 Add `~/.copilot` to credential deny lists in claude-code/CLAUDE.md and codex/AGENTS.md.

## Phase 3: User Story 1 - Aligned guardrails (Priority: P1)

### Tests

- [X] T005 [P] [US1] Test: copilot-instructions.md lists same ~50 credential paths as CLAUDE.md.
- [X] T006 [P] [US1] Test: lists preferred CLI tools in same order as CLAUDE.md.

### Implementation

- [X] T007 [US1] Author `copilot-instructions.md` with Guardrails, Preferred CLI Tools, MCP Servers, Working Style sections.

## Phase 4: User Story 2 - Devcontainer rebuild refresh (Priority: P2)

### Tests

- [X] T008 [P] [US2] Test: pre-seed stale ~/.copilot/copilot-instructions.md in devcontainer; rebuild; assert replaced.

### Implementation

- [X] T009 [US2] Already implemented in T003 (`_deploy_configs` branches on `is_devcontainer`).

## Phase 5: Polish

- [X] T010 Run `make lint`; expect 0 warnings (no shell scripts to lint here).
- [X] T011 Run `tests/test-consistency.sh`; expect parity.

## Dependencies

Phase 1 -> Phase 2 -> Phases 3-4 -> Phase 5.

## Implementation Strategy

Single MVP.
Simple capability; ship in one PR.
