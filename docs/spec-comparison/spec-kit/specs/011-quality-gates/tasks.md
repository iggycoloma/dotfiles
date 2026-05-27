# Tasks: Quality Gates

## Phase 1: Setup

- [X] T001 Create Makefile with `lint`, `test`, `test-<suite>`,
       `lint-devcontainers`, `lint-settings-drift` targets. `lint`
       declares `lint-settings-drift lint-devcontainers` as
       prerequisites so they run before shellcheck.
- [X] T002 [P] Create `.github/workflows/ci.yml` skeleton with matrix.

## Phase 2: Foundational

- [X] T003 Implement `make lint`: `find . -name '*.sh' -not -path
       './.git/*' -not -path './.devcontainer/*' | xargs shellcheck`.
- [X] T004 Implement test suite skeletons under `tests/`.

## Phase 3: User Story 1 - Lint blocks merge (P1)

### Tests
- [X] T005 [P] [US1] Validate that adding a known-bad shell script
       fails `make lint` in CI.

### Implementation
- [X] T006 [US1] CI step: run `make lint`; fail the job on non-zero
       exit.
- [X] T007 [US1] Branch protection: require `lint` status check
       before merge to main.

## Phase 4: User Story 2 - Full matrix (P1)

### Tests
- [X] T008 [P] [US2] Verify the matrix expands to 13+ cells in CI
       run logs.
- [X] T009 [P] [US2] Verify each cell runs `./install.sh` followed
       by `make test`.

### Implementation
- [X] T010 [US2] Define matrix in ci.yml: distros (Ubuntu 20/22/24,
       Debian 11/12, Alpine, macOS 15/26), shells (bash, zsh).
- [X] T011 [US2] CI step per cell: install deps, run installer, run
       tests.
- [X] T012 [US2] Branch protection: require all matrix cells before
       merge.

## Phase 5: User Story 3 - Consistency check (P2)

### Tests
- [X] T013 [P] [US3] Test: pre-seed mismatched deny lists across
       CLAUDE.md / AGENTS.md / copilot-instructions.md; assert
       test-consistency reports the mismatch.

### Implementation
- [X] T014 [US3] Implement `tests/test-consistency.sh`: parse deny
       lists from each file; diff; report missing entries.

## Phase 5a: Settings drift + dc-audit promotion

### Tests

- [X] T014a [P] Test (`tests/test-settings-drift.sh`): edit
       `claude-code/settings.json` to add a permission entry; assert
       `bin/settings-drift.sh --quiet` exits non-zero with a drift
       report. Add the equivalent entry to
       `settings.container.json`; assert exit 0.
- [X] T014b [P] Test: delete `codex/config.container.toml`; assert
       `settings-drift.sh` reports the missing variant as drift, not
       a clean skip.
- [X] T014c [P] Test (`tests/test-dc-audit.sh`): seed an attended
       `.devcontainer/foo/devcontainer.json` with `runArgs: ["--network=host"]`;
       assert `make lint` exits non-zero. Downgrade to a Warn-severity
       finding; assert `make lint` exits 0 with the warning surfaced.

### Implementation

- [X] T014d Author `bin/settings-drift.sh`: diff host vs container
       variant pair, skip the sandbox-specific keys, report any other
       asymmetric edit. Treat missing-variant as drift.
- [X] T014e Promote `lint-devcontainers` to a `make lint` prerequisite
       in the Makefile (sequence: `lint-settings-drift lint-devcontainers`
       then `shellcheck`).

## Phase 6: Polish

- [X] T015 Add `lint-devcontainers` Makefile target as a `make lint`
       prerequisite (Error severity fails build; Warn/Info advisory).
- [X] T016 Add pr-title.yml workflow enforcing conventional-commits
       on PR titles.
- [X] T017 Document the matrix in README.md "Supported Platforms"
       section.

## Dependencies

Phase 1 -> Phase 2 -> Phases 3-5 (parallel) -> Phase 6.

## Implementation Strategy

MVP is User Stories 1 + 2 (lint + matrix). Story 3 (consistency)
catches a known recurring drift; ship as a follow-up if MVP is
under time pressure.
