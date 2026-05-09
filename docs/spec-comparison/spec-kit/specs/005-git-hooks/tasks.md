# Tasks: Git Hooks

## Phase 1: Setup

- [X] T001 Create `git/hooks/commit-msg` and `git/hooks/pre-commit`
       skeletons with `set -euo pipefail`.
- [X] T002 [P] Create `claude-code/hooks/shared-patterns.sh` exposing
       `has_ai_attribution`, `has_coauthor_tag`, `has_emoji` functions.
- [X] T003 [P] Create `tests/test-security-hook.sh` skeleton with case
       runner.

## Phase 2: Foundational

- [X] T004 In both hooks, source `shared-patterns.sh` with fallback to
       inline regex if not found (works when hooks deployed standalone).
- [X] T005 In both hooks, set `DOTFILES_GLOBAL_HOOK_RUNNING=1` recursion
       guard.
- [X] T006 In both hooks, delegate to `<git-dir>/hooks/<hook>.local`
       (and the non-`.local` variant for commit-msg) before any global
       check.

## Phase 3: User Story 1 - Conventional commits enforced (Priority: P1)

### Tests

- [X] T007 [P] [US1] Test 25 cases: valid conv-commit subjects accepted.
- [X] T008 [P] [US1] Test 30 cases: invalid subjects rejected (missing
       type, wrong format, too short, etc.).
- [X] T009 [P] [US1] Test 10 cases: AI attribution patterns rejected.
- [X] T010 [P] [US1] Test 5 cases: co-author lines rejected.
- [X] T011 [P] [US1] Test 8 cases: emoji ranges rejected.
- [X] T012 [P] [US1] Test 5 cases: merge commits pass through.
- [X] T013 [P] [US1] Test 6 cases: recursion guard short-circuits.

### Implementation

- [X] T014 [US1] Implement conv-commits regex check in `commit-msg`.
- [X] T015 [US1] Implement subject length check (>= 10).
- [X] T016 [US1] Implement merge-commit pass-through.
- [X] T017 [US1] Wire `_check_attribution`, `_check_coauthor`,
       `_check_emoji` (using shared-patterns or inline fallback).

## Phase 4: User Story 2 - Gitleaks (Priority: P1)

### Tests

- [X] T018 [P] [US2] Test: stage AWS key, attempt commit, assert exit
       non-zero.
- [X] T019 [P] [US2] Test: stage clean file, attempt commit, assert
       success.
- [X] T020 [P] [US2] Test: gitleaks not installed -> hook exits 0
       silently.

### Implementation

- [X] T021 [US2] Add gitleaks invocation in `pre-commit`; gate on
       `command -v gitleaks`.
- [X] T022 [US2] Add user-facing message on gitleaks failure
       (review, .gitleaksignore, --no-verify).

## Phase 5: User Story 3 - Per-repo escape hatch (Priority: P2)

### Tests

- [X] T023 [P] [US3] Test: create `.git/hooks/commit-msg.local`
       requiring "FOO-NNN", attempt commit without ticket, assert
       global hook delegates and aborts.

### Implementation

- [X] T024 [US3] Already implemented in T006 (Phase 2). No additional
       work; just verify in tests.

## Phase 6: Polish

- [X] T025 Update README.md "Security Model" section to document hook
       layering and `--no-verify` escape.
- [X] T026 Run `make lint`; expect 0 warnings.
- [X] T027 Run `bash tests/test-security-hook.sh`; expect all 89+ cases
       pass.

## Dependencies

Phase 1 -> Phase 2 -> Phases 3, 4, 5 (parallel possible since they
exercise independent hook code paths) -> Phase 6.

## Implementation Strategy

MVP is User Story 1 (conv-commits + AI attribution). Story 2 (gitleaks)
and Story 3 (escape hatch) layer on after.
