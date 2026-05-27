# Implementation Plan: Install

**Branch**: `001-install` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/001-install/spec.md`

## Summary

Single-entrypoint installer driven by environment detection. POSIX-compatible
bash, `set -u` for early failure, a tiny CLI surface (`--with-unattended` only),
and `DOTFILES_NO_*` opt-out toggles. On hosts: symlinks to the repo. In
devcontainers: stomp-copies for per-boot freshness. Variant files
(host vs container) are deployed via `_deploy_variant_file`. Strict idempotency.

## Technical Context

| Field                    | Value                                                                                |
|--------------------------|--------------------------------------------------------------------------------------|
| **Language/Version**     | Bash (POSIX-compatible; macOS bash 3.2 is the floor)                                 |
| **Primary Dependencies** | None (bash + standard utils: cp, mv, ln, mkdir, chmod, grep)                         |
| **Storage**              | Filesystem only: target paths under `$HOME` and `$HOME/.config/`                     |
| **Testing**              | `tests/test-install.sh`, `tests/unit-tests.sh` (hand-rolled bash assertions)         |
| **Target Platform**      | macOS 15+/26, Ubuntu 20.04/22.04/24.04, Debian 11/12, Alpine, Codespaces             |
| **Project Type**         | Single project (CLI installer)                                                       |
| **Performance Goals**    | Cold install <90s; re-run <20s; self-edit auto-skip <1s                              |
| **Constraints**          | Must run in CI without TTY; must work without `git` or `curl` on PATH for early-exit detection; macOS bash 3.2; Linux hosts need `bubblewrap` + `socat` (paired) for the Claude Code sandbox |
| **Scale/Scope**          | One developer, three deployment targets, ~30 tools                                  |

## Constitution Check

| Article                                       | Status  | Notes                                                                                  |
|-----------------------------------------------|---------|----------------------------------------------------------------------------------------|
| I. Developer-Specific, Not Project-Specific   | PASS    | Installer only deploys universal tools and AI-tool config; no project tooling.         |
| II. Defense-in-Depth Security                 | PASS    | Installer never reads credentials; SSH signing setup uses public keys only.            |
| III. Cross-Platform Parity                    | PASS    | Tested on every matrix cell; bash 3.2 floor respected (no associative arrays, etc.).   |
| IV. Idempotent and Reversible Installs        | PASS    | Backups created on replacement; re-run is no-op; all changes reversible from backup.   |
| V. Opt-In for High-Risk Surface               | PASS    | `--with-unattended` is opt-in; SSH signing auto-detect is opt-out (`DOTFILES_NO_SSH_SIGNING`). |

**Result**: All articles pass. No Complexity Tracking entries required.

## Project Structure

### Documentation (this feature)

```
specs/001-install/
|-- spec.md
|-- plan.md           (this file)
+-- tasks.md
```

(No `research.md`, `contracts/`, or `data-model.md` -- the feature has no
external API, no data model beyond filesystem paths, and no design unknowns.)

### Source Code (repository root)

```
install.sh                       # Entrypoint
bootstrap/
|-- detect.sh                    # Environment / OS / package manager / state-tier
|-- logging.sh                   # log_info / log_section / log_success / log_warn / log_error
|-- packages.sh                  # install_packages (delegated to spec 002-packages)
|-- symlinks.sh                  # create_symlinks + per-tool _setup_* helpers
+-- completions.sh               # setup_completions (delegated to spec 003-shell)
```

### Structure Decision

**Pattern**: Single Project. The installer is a single bash entrypoint with
delegated phase scripts under `bootstrap/`. No web/mobile distinction; no
client/server split.

## Complexity Tracking

(empty -- no constitution violations to justify)

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|-----------|--------------------------------------|
|           |           |                                      |
