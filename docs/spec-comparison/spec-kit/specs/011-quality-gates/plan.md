# Implementation Plan: Quality Gates

**Branch**: `011-quality-gates` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)

## Summary

Lint = shellcheck on every `*.sh`. Tests = 7 hand-rolled bash suites
under `tests/`. CI = GitHub Actions matrix across 13+ platform
combinations. All required for merge except `lint-devcontainers`
(advisory).

## Technical Context

| Field             | Value                                                                                          |
|-------------------|------------------------------------------------------------------------------------------------|
| Language/Version  | shellcheck (any modern); bash for tests                                                        |
| Dependencies      | shellcheck, bash, GitHub Actions runners                                                       |
| Storage           | Test fixtures under `tests/fixtures/` (when needed)                                            |
| Testing           | n/a (this IS the testing infrastructure)                                                       |
| Target Platform   | All (the matrix IS the target)                                                                 |
| Project Type      | Single Project                                                                                 |
| Performance Goals | Full matrix run < 15 min wall-clock                                                            |
| Constraints       | Tests must run without external services; macOS minutes are budgeted                           |
| Scale/Scope       | 7 suites, 13+ matrix cells, ~150 individual test cases                                        |

## Constitution Check

| Article                            | Status | Notes                                                                       |
|------------------------------------|--------|------------------------------------------------------------------------------|
| I. Developer-Specific              | PASS   | Universal QA infra.                                                          |
| II. Defense-in-Depth Security      | PASS   | Tests verify the security model (security-hook test, consistency test).      |
| III. Cross-Platform Parity         | PASS   | This capability IS the parity guarantee.                                     |
| IV. Idempotent and Reversible      | PASS   | Tests are idempotent; fixtures restored after each run.                      |
| V. Opt-In for High-Risk Surface    | PASS   | `lint-devcontainers` is advisory (opt-in for CI).                            |

## Project Structure

```
Makefile
tests/
|-- unit-tests.sh, test-packages.sh, test-install.sh, test-consistency.sh,
|-- test-policy.sh, test-ralph.sh, test-dc-audit.sh, test-security-hook.sh,
+-- test-functions.sh, validate-dotfiles.sh
.github/workflows/
|-- ci.yml          Main matrix
+-- pr-title.yml    Conventional-commits check on PR titles
```

### Structure Decision

Single Project. No bats / pytest / etc. -- the test suites are bash
scripts that the Makefile wraps. Trade-off: less framework support, but
no extra dependency.

## Complexity Tracking

(empty)
