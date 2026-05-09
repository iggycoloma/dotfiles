# Implementation Plan: Packages

**Branch**: `002-packages` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)

## Summary

Per-OS install routing: macOS uses Homebrew exclusively, Linux prefers
GitHub releases (musl-static, SHA-256 verified) for tools with active
upstream releases, falling back to apt/apk for distro-friendly tools.
Idempotent (skip if version is current). Honors AI-tool and atuin opt-outs.

## Technical Context

| Field                | Value                                                                               |
|----------------------|--------------------------------------------------------------------------------------|
| Language/Version     | Bash (POSIX)                                                                         |
| Primary Dependencies | curl, tar, sha256sum, jq (for GitHub API), brew (macOS) / apt (Debian) / apk (Alpine) |
| Storage              | `~/.local/bin/`, `~/.cargo/bin/`, distro-managed paths                              |
| Testing              | `tests/test-packages.sh`                                                             |
| Target Platform      | macOS, Ubuntu, Debian, Alpine, Codespaces                                            |
| Project Type         | Single Project                                                                       |
| Performance Goals    | Cold install <2min; re-install <10s                                                  |
| Constraints          | No version pinning; checksum verification mandatory on Linux                         |
| Scale/Scope          | ~30 tools across 4 tiers                                                             |

## Constitution Check

| Article                                | Status | Notes                                                                       |
|----------------------------------------|--------|------------------------------------------------------------------------------|
| I. Developer-Specific                  | PASS   | Only universal/agentic tools; gh/docker/kubectl excluded.                    |
| II. Defense-in-Depth Security          | PASS   | SHA-256 verification on every Linux download.                                |
| III. Cross-Platform Parity             | PASS   | Tested on every matrix cell.                                                 |
| IV. Idempotent and Reversible          | PASS   | Re-install of current version is no-op; backups via package manager.         |
| V. Opt-In for High-Risk Surface        | PASS   | AI tools default-on but opt-out via `DOTFILES_NO_AI_TOOLS=1`.                |

**Result**: All articles pass.

## Project Structure

### Documentation

```
specs/002-packages/{spec.md, plan.md, tasks.md}
```

### Source Code

```
bootstrap/packages.sh                 # install_packages + per-tool helpers
```

### Structure Decision

Single Project. The packages logic is one file (`bootstrap/packages.sh`)
with per-tool functions; routing per OS happens at function entry.

## Complexity Tracking

(empty)
