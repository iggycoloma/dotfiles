# quality-gates

## Overview

Linting and test infrastructure: shellcheck on every shell script,
seven hand-rolled bash test suites covering install, packages, security
hooks, functions, dc-audit, ralph, and policy. GitHub Actions matrix runs
across 13+ platform configurations on every PR.

## Requirements

### Lint

- `make lint` MUST run shellcheck on every `*.sh` file in the repo
  excluding `.git/` and `.devcontainer/` configs.
- shellcheck MUST exit non-zero on any warning of severity warning or
  higher.
- CI MUST block merge on `make lint` failure.
- New `# shellcheck disable=` directives MUST be accompanied by an
  inline comment explaining why.

### Test suites

- `make test` MUST run all of: `test-unit`, `test-packages`,
  `test-integration`, `test-consistency`, `test-policy`, `test-ralph`,
  `test-dc-audit`.
- `tests/unit-tests.sh` MUST cover bootstrap functions (symlinks,
  backups, merge logic, git include detection).
- `tests/test-packages.sh` MUST cover package installation (presence
  on PATH, version resolution, idempotency).
- `tests/test-install.sh` (alias `test-integration`) MUST run the full
  `./install.sh` against a fresh container image and assert post-state
  invariants (symlinks present, tools resolvable, shell startup works,
  `dotfiles-doctor` reports green).
- `tests/test-consistency.sh` MUST verify that the dotfiles AGENTS.md
  list, the deployed `~/.claude/CLAUDE.md`, the deployed `~/.codex/AGENTS.md`,
  and the deployed `~/.copilot/copilot-instructions.md` agree on the
  credential deny lists and the preferred-tool list.
- `tests/test-policy.sh` MUST verify the gh repo policy (branch
  protection on main, required status checks).
- `tests/test-ralph.sh` MUST exercise ralph's exit-code handling and
  circuit breaker.
- `tests/test-dc-audit.sh` MUST exercise dc-audit's rule engine and
  --fix behavior.
- `tests/test-security-hook.sh` MUST cover at least 89 cases for the
  commit-msg hook (conventional commits regex, AI attribution patterns,
  emoji ranges, merge-commit pass-through, recursion guard).
- `tests/test-functions.sh` MUST cover shell functions (extract,
  killport, gcof, glf, smart cat).

### CI matrix

- The GitHub Actions workflow MUST test on Ubuntu 20.04, 22.04, 24.04;
  Debian 11, 12; Alpine latest; macOS 15, 26 (where applicable). For
  shell variations, both bash and zsh.
- The matrix MUST be cross-product of distro x shell x package manager
  for at least 13 cells.
- A failure in any cell MUST block merge.

### Devcontainer audit

- `make lint-devcontainers` MUST run `bin/dc-audit.sh` against every
  `.devcontainer/*/devcontainer.json` in this repo.
- The unattended profile MUST be audited under `--profile unattended`;
  others under `--profile attended`.
- `lint-devcontainers` is advisory (not part of `make test`); failures
  do not block merge.

## Scenarios

### Scenario: Adding a shell script triggers shellcheck

GIVEN a developer adds `bootstrap/foo.sh`
WHEN they run `make lint`
THEN shellcheck checks the new file
AND reports any warnings
AND exits non-zero if warnings are present.

### Scenario: Full test matrix on PR

GIVEN a developer opens a PR
WHEN GitHub Actions runs the workflow
THEN the matrix expands to 13+ cells
AND each cell runs `./install.sh` followed by `make test`
AND merge is blocked until every cell passes.

### Scenario: Consistency test catches drift

GIVEN a developer adds a new credential pattern to `claude-code/CLAUDE.md`
AND forgets to add it to `codex/AGENTS.md` and `copilot/copilot-instructions.md`
WHEN `make test-consistency` runs
THEN the test compares the deny lists across the three files
AND reports the missing pattern in Codex/Copilot
AND exits non-zero.

### Scenario: dc-audit advisory passes lint

GIVEN `.devcontainer/example/devcontainer.json` has a minor warning
WHEN `make lint-devcontainers` runs
THEN dc-audit reports the warning
AND `make lint-devcontainers` exits non-zero (advisory)
AND `make test` (which does not include lint-devcontainers) still passes.

## Non-Behavior

- `make test` does NOT run `make lint-devcontainers` (advisory only).
- The test suites do NOT use bats or any other framework -- raw bash
  with explicit `[[ ... ]]` assertions.
- The test suites do NOT mock external commands (no command stubs);
  tests run against real binaries.
- CI does NOT run on macOS for every PR (cost trade-off; macOS cells
  run on a nightly schedule).
- CI does NOT require code coverage -- behavior coverage via test
  assertions is sufficient for shell code.
