# Feature Specification: Quality Gates

**Branch**: `011-quality-gates` | **Date**: 2026-04-01 | **Status**: Implemented

## User Scenarios & Testing

### User Story 1 - Lint blocks merge (Priority: P1)

A developer's PR cannot merge until `make lint` passes. `make lint`
runs three checks in order:

1. `lint-settings-drift` -- `bin/settings-drift.sh` compares the host vs
   container variant pair (`claude-code/settings.json` vs
   `settings.container.json`; `codex/config.toml` vs
   `config.container.toml`) for asymmetric edits.
2. `lint-devcontainers` -- `bin/dc-audit.sh` audits every
   `.devcontainer/*/devcontainer.json` against its profile (attended /
   unattended). Error severity fails the build; Warn/Info are advisory.
3. `shellcheck` -- runs over every `*.sh` in the repo.

**Acceptance Scenarios**:
```
GIVEN a PR adding bootstrap/foo.sh with a shellcheck warning
WHEN GitHub Actions runs `make lint`
THEN shellcheck reports the warning
  AND make lint exits non-zero
  AND the merge button is disabled (required status check failed)

GIVEN a PR that adds a permission to claude-code/settings.json but
  forgets to add the equivalent to settings.container.json
WHEN GitHub Actions runs `make lint`
THEN lint-settings-drift reports the asymmetric edit
  AND make lint exits non-zero before shellcheck even runs

GIVEN a PR that adds an Error-severity finding to .devcontainer/foo/
  devcontainer.json (e.g. host network in an attended profile)
WHEN GitHub Actions runs `make lint`
THEN lint-devcontainers (dc-audit) reports the Error
  AND make lint exits non-zero
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

- **Lint warning in `unattended/`**: blocks merge same as elsewhere
  (no exemption for opt-in code).
- **macOS-only test fails**: blocks merge for that cell; cannot
  bypass via "skip mac" label.
- **`make lint-devcontainers` Warn/Info finding**: advisory only;
  does NOT block merge. Only Error-severity findings from `dc-audit`
  fail `make lint`.
- **Missing container variant**: `settings-drift.sh` treats a missing
  variant file (e.g. `claude-code/settings.container.json` deleted but
  `settings.json` still present) as drift, not as a clean skip.

## Requirements

### Functional Requirements

- **FR-001** `make lint` MUST run, in order, `lint-settings-drift`,
  `lint-devcontainers`, and then `shellcheck` on every `*.sh`
  excluding `.git/` and `.devcontainer/` configs. The first two are
  declared as prerequisites of the `lint` target; if either exits
  non-zero, shellcheck is not run.
- **FR-002** shellcheck MUST exit non-zero on warning severity or
  higher.
- **FR-003** CI MUST block merge on `make lint` failure.
- **FR-004** `make test` MUST run all 7 suites: test-unit,
  test-packages, test-integration, test-consistency, test-policy,
  test-ralph, test-dc-audit. `make test` MUST NOT run
  `lint-devcontainers` or `lint-settings-drift` -- those belong to
  `make lint`.
- **FR-005** Each test suite MUST be runnable independently
  (`make test-<suite>`).
- **FR-006** GitHub Actions MUST exercise 13+ matrix cells per PR.
- **FR-007** A failure in any matrix cell MUST block merge.
- **FR-008** `make lint-devcontainers` MUST be a prerequisite of
  `make lint`, not an advisory side-target. `bin/dc-audit.sh` MUST
  exit non-zero on Error-severity findings; Warn and Info are
  surfaced as advisory hints but MUST NOT fail the build. The
  attended / unattended profile assignment per directory MUST be
  locked by `tests/test-dc-audit.sh`.
- **FR-009** New `# shellcheck disable=` MUST be accompanied by an
  inline comment explaining why.
- **FR-010** `bin/settings-drift.sh` MUST lint the host vs container
  variant pair for asymmetric edits. A missing variant file (one of
  the pair deleted) MUST be reported as drift, not silently skipped.
  Run as `lint-settings-drift`, it is a prerequisite of `make lint`.

### Key Entities

- **Test suite**: hand-rolled bash file under `tests/` with a
  `make test-<name>` target.
- **Matrix cell**: one (distro, shell, package-manager) combination;
  pinned in `.github/workflows/ci.yml`.
- **Variant pair**: a (host, container) file pair such as
  `claude-code/settings.json` + `settings.container.json` or
  `codex/config.toml` + `config.container.toml`. `settings-drift.sh`
  asserts both members exist and that non-sandbox keys stay in sync.
- **dc-audit severity**: `Error | Warn | Info`. Only `Error` fails
  `make lint`.

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
