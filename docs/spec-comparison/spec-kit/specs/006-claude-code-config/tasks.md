# Tasks: Claude Code Configuration

## Phase 1: Setup

- [X] T001 Create `claude-code/CLAUDE.md` skeleton with sections: Guardrails, Deny-list semantics, Skill trigger precedence, MCP Servers, Tool Use Discipline, Preferred CLI Tools, Structural Code Search, File Watching.
- [X] T002 [P] Create both settings variants: `claude-code/settings.json` (host: `sandbox.enabled: true`, `allowedDomains`, `allowUnixSockets` for ssh-agent) and `claude-code/settings.container.json` (container: `sandbox.enabled: false`).
  Same `permissions`, `hooks`, `statusLine`, `attribution` in both.
- [X] T002b Add `bin/settings-drift.sh` lint comparing key-value pairs across the two variants; fails on asymmetric edits and on missing variants.
  Wire into `make lint` via `lint-settings-drift`.
  `alwaysThinkingEnabled` keys.
- [X] T003 [P] Create `claude-code/statusline.sh` skeleton.

## Phase 2: Foundational

- [X] T004 Create `claude-code/hooks/shared-patterns.sh` with `has_ai_attribution`, `has_coauthor_tag`, `has_emoji` functions (consumed by 005-git-hooks too).
- [X] T005 Create `claude-code/hooks/pre-security.sh` skeleton with SENSITIVE_PATHS, SENSITIVE_EXTENSIONS, SENSITIVE_DIRS, SENSITIVE_FILES, SENSITIVE_GLOB_PATTERNS arrays.
- [X] T006 [P] (deprecated) `pre-commit-validate.sh` was originally added here as a Claude-proposal-time mirror of the git `commit-msg` hook.
  It has since been removed: commit-message validation now lives only in the global git `commit-msg` hook wired via `core.hooksPath`.
  The duplicate hook drifted in practice; single source of truth is cleaner.
  Left as a marker so downstream task numbering stays stable.
- [X] T007 [P] Create `claude-code/hooks/pre-code-no-emoji.sh` skeleton (Write/Edit emoji block).

## Phase 3: User Story 1 - Safe by default (Priority: P1)

### Tests for User Story 1

- [X] T008 [P] [US1] Test 35 cases in `tests/test-security-hook.sh` covering each deny pattern in settings.json (`.env`, `**/credentials*`, `**/*.pem`, `~/.ssh/**`, etc.).
- [X] T009 [P] [US1] Test 20 cases for pre-security.sh Bash command string scanning (catches `cat ~/.aws/credentials`, `ls ~/.kube/config`).
- [X] T010 [P] [US1] Test 5 cases for path traversal: deny (`../../etc/passwd`, etc.).

### Implementation for User Story 1

- [X] T011 [US1] Populate settings.json `deny` with ~35 credential globs and Bash destructive patterns.
- [X] T012 [US1] Populate settings.json `allow` with ~70 Bash command prefixes (git read, gh read, ls, find, etc.).
- [X] T013 [US1] Implement pre-security.sh Bash branch (scan command string against SENSITIVE_PATHS/DIRS/FILES/GLOB_PATTERNS).
- [X] T014 [US1] Implement pre-security.sh file-tool branch (check file_path against SENSITIVE_PATHS/EXTENSIONS, deny on `..`).

## Phase 4: User Story 2 - 4-stage pipeline (Priority: P1)

### Tests for User Story 2

- [X] T015 [P] [US2] Test: `/pipeline` invocation spawns pm-spec sub-agent with constrained tools.
- [X] T016 [P] [US2] Test: between stages, the user receives a checkpoint prompt.

### Implementation for User Story 2

- [X] T017 [US2] Create `claude-code/agents/pm-spec.md` with frontmatter declaring tools: Read, Grep, Write.
- [X] T018 [US2] Create `claude-code/agents/architect-review.md` (Read, Grep, Glob).
- [X] T019 [US2] Create `claude-code/agents/implementer-tester.md` (Read, Write, Edit, Bash).
- [X] T020 [US2] Create `claude-code/agents/qa-reviewer.md` (Read, Bash, Grep, Glob).
- [X] T021 [US2] Create `claude-code/agents/code-reviewer.md` (Read, Grep, Glob, Bash).
- [X] T022 [US2] Create `claude-code/commands/pipeline.md` orchestrating the 4 stages with explicit user-checkpoint instructions.

## Phase 5: User Story 3 - SessionStart banner (Priority: P2)

### Tests for User Story 3

- [X] T023 [P] [US3] Test: SessionStart hook fires; output contains "no emoji" and "conventional commits" reminders.

### Implementation for User Story 3

- [X] T024 [US3] Create `claude-code/hooks/session-start-banner.sh` emitting the reminder text.
- [X] T025 [US3] Wire SessionStart hook in settings.json.

## Phase 6: User Story 4 - Idle Pushover (Priority: P3)

### Tests for User Story 4

- [X] T026 [P] [US4] Test: with PUSHOVER_TOKEN set, simulate idle_prompt; assert curl-to-pushover invocation.
- [X] T027 [P] [US4] Test: without PUSHOVER_TOKEN, hook silent no-op (exit 0, no network call).

### Implementation for User Story 4

- [X] T028 [US4] Create `claude-code/hooks/notify.sh` (curl Pushover API with title + message).
- [X] T029 [US4] Wire Notification hook on `idle_prompt`.

## Phase 7: Slash commands

- [X] T030 [P] Create `commit.md`, `pr-create.md`, `review-pr.md`.
- [X] T031 [P] Create `security-audit.md`, `feature-spec.md`, `debug.md`, `test.md`, `optimize.md`.
- [X] T032 [P] Create `dependencies.md`, `refactor.md`, `deploy-checklist.md`, `docs.md`, `changelog.md`, `fix-issue.md`, `context-prime.md`.

## Phase 8: Statusline

- [X] T033 Implement `statusline.sh`: git branch, working-tree dirty indicator, context-usage progress bar (read from Claude's stdin JSON), model name.

## Phase 9: Polish

- [X] T034 Run `make lint`; expect 0 warnings.
- [X] T035 Run `tests/test-security-hook.sh`; expect 89+ passing.
- [X] T036 Run `tests/test-consistency.sh`; expect deny-list parity across CLAUDE.md, codex/AGENTS.md, copilot/copilot-instructions.md.

## Dependencies & Execution Order

Phase 1 -> Phase 2 -> Phase 3 (security; blocks everything else shipping safely) -> Phase 4 (pipeline; high value) -> Phase 5 (banner) -> Phase 6 (notify) -> Phase 7 (commands; can parallelize) -> Phase 8 (statusline) -> Phase 9 (polish).

## Parallel Example: Slash commands (Phase 7)

T030, T031, T032 each touch disjoint files in `claude-code/commands/`; all three can run in parallel.

## Implementation Strategy

MVP is User Story 1 (safe by default).
Without it, every other story is risky to ship.
Layer 2 (pipeline) is the high-leverage workflow piece. 3 and 4 are quality-of-life.
