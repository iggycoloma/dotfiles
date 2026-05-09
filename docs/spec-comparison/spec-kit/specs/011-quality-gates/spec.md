# Feature Specification: Quality Gates

**Branch**: `011-quality-gates` | **Date**: 2026-04-01 | **Status**: Implemented

## User Scenarios & Testing

### User Story 1 - Lint blocks merge (Priority: P1)

A developer's PR cannot merge until shellcheck passes on every `*.sh`
file in the repo.

**Acceptance Scenarios**:
```
GIVEN a PR adding bootstrap/foo.sh with a shellcheck warning
WHEN GitHub Actions runs `make lint`
THEN shellcheck reports the warning
  AND make lint exits non-zero
  AND the merge button is disabled (required status check failed)
```

### User Story 2 - Full matrix on every PR (Priority: P1)

A PR triggers tests on 13+ platform configurations
(distro x shell x package manager).

**Acceptance Scenarios**:
```
GIVEN a developer opens a PR
WHEN GitHub Actions runs the workflow
THEN the matrix expands to 13+ cells (Ubuntu 20/22/24, Debian 11/12,
  Alpine, macOS 15/26, Codespaces; bash + zsh per applicable cell)
  AND each cell runs ./install.sh + make test
  AND merge is blocked until every cell passes
```

### User Story 3 - Consistency check across instruction files (Priority: P2)

A developer adding a credential pattern to `claude-code/CLAUDE.md`
forgets to add it to `codex/AGENTS.md`. The consistency test catches
the drift before merge.

**Acceptance Scenarios**:
```
GIVEN a PR adds a new credential pattern to claude-code/CLAUDE.md only
WHEN make test-consistency runs
THEN the test compares deny lists across CLAUDE.md, codex/AGENTS.md,
  copilot/copilot-instructions.md, and the deployed settings.json
  AND reports the missing pattern in the codex/copilot files
  AND exits non-zero
```

### Edge Cases

- **Lint warning in `agentic/`**: blocks merge same as elsewhere
  (no exemption for opt-in code).
- **macOS-only test fails**: blocks merge for that cell; cannot
  bypass via "skip mac" label.
- **`make lint-devcontainers` warning**: advisory only; does NOT
  block merge.

## Requirements

### Functional Requirements

- **FR-001** `make lint` MUST run shellcheck on every `*.sh`
  excluding `.git/` and `.devcontainer/` configs.
- **FR-002** shellcheck MUST exit non-zero on warning severity or
  higher.
- **FR-003** CI MUST block merge on `make lint` failure.
- **FR-004** `make test` MUST run all 7 suites: test-unit,
  test-packages, test-integration, test-consistency, test-policy,
  test-ralph, test-dc-audit.
- **FR-005** Each test suite MUST be runnable independently
  (`make test-<suite>`).
- **FR-006** GitHub Actions MUST exercise 13+ matrix cells per PR.
- **FR-007** A failure in any matrix cell MUST block merge.
- **FR-008** `make lint-devcontainers` MUST be advisory (not part of
  `make test`).
- **FR-009** New `# shellcheck disable=` MUST be accompanied by an
  inline comment explaining why.

### Key Entities

- **Test suite**: hand-rolled bash file under `tests/` with a
  `make test-<name>` target.
- **Matrix cell**: one (distro, shell, package-manager) combination;
  pinned in `.github/workflows/ci.yml`.

## Success Criteria

- **SC-001** Zero merges with shellcheck warnings (CI audit).
- **SC-002** Every test suite passes on every matrix cell.
- **SC-003** Consistency drift caught within the same PR that
  introduces it (test-consistency runs on every PR).

## Assumptions

- shellcheck remains the canonical bash linter.
- GitHub Actions runners continue to support the matrix cells we
  target.
- The cost of macOS minutes is acceptable; if it becomes prohibitive,
  macOS moves to nightly per the constitution amendment process.
