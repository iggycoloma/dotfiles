# quality-gates

## Overview

Linting and test infrastructure: shellcheck on every shell script,
seven hand-rolled bash test suites covering install, packages, security
hooks, functions, dc-audit, ralph, and policy. GitHub Actions matrix runs
across 13+ platform configurations on every PR.

## Requirements

### Lint

- `make lint` MUST run, in order: `lint-settings-drift`,
  `lint-devcontainers`, then shellcheck on every `*.sh` file in the repo
  excluding `.git/` and `.devcontainer/` configs.
- shellcheck MUST exit non-zero on any warning of severity warning or
  higher.
- CI MUST block merge on `make lint` failure.
- New `# shellcheck disable=` directives MUST be accompanied by an
  inline comment explaining why.

### Settings drift

- `bin/settings-drift.sh` MUST compare key-value pairs between the host
  and container variants of every variant file (`claude-code/settings.json`
  vs. `settings.container.json`; `codex/config.toml` vs.
  `config.container.toml`) and report any mismatch outside the
  documented sandbox-block exception.
- A missing variant (only one side of the pair exists) MUST be reported
  as drift, not skipped silently.
- `make lint-settings-drift` MUST invoke the linter with `--quiet` and
  fail the build on non-zero exit.

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
- The unattended profile (`.devcontainer/unattended/*`) MUST be audited
  under `--profile unattended`; every other `.devcontainer/*` MUST be
  audited under `--profile attended`. The profile-to-directory mapping
  MUST be exercised by `tests/test-dc-audit.sh`.
- `lint-devcontainers` MUST be a prerequisite of `make lint`. It fails
  the build only on Error-severity findings; Info/Warn findings are
  advisory hints that do NOT block merge.

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

### Scenario: dc-audit warning is advisory under make lint

GIVEN `.devcontainer/example/devcontainer.json` has a Warn-severity finding
WHEN `make lint` runs
THEN `lint-devcontainers` reports the warning
AND exits 0 (Warn does not fail the build)
AND `make lint` continues to shellcheck.

### Scenario: dc-audit Error fails make lint

GIVEN `.devcontainer/unattended/devcontainer.json` is missing
`--cap-drop=ALL` (rated Error under `--profile unattended`)
WHEN `make lint` runs
THEN `lint-devcontainers` reports the Error
AND exits non-zero
AND `make lint` blocks merge.

### Scenario: settings-drift catches asymmetric edit

GIVEN a developer adds `"allow": ["Bash(npm install:*)"]` to
`claude-code/settings.json` but forgets `settings.container.json`
WHEN `make lint-settings-drift` runs
THEN the linter reports the missing key in the container variant
AND exits non-zero
AND `make lint` blocks merge.

## Non-Behavior

- `make test` does NOT run `make lint-devcontainers` (lives under
  `make lint` instead; advisory at Warn, blocking at Error).
- The test suites do NOT use bats or any other framework -- raw bash
  with explicit `[[ ... ]]` assertions.
- The test suites do NOT mock external commands (no command stubs);
  tests run against real binaries.
- CI does NOT run on macOS for every PR (cost trade-off; macOS cells
  run on a nightly schedule).
- CI does NOT require code coverage -- behavior coverage via test
  assertions is sufficient for shell code.
