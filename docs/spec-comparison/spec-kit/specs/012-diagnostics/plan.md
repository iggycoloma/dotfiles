# Implementation Plan: Diagnostics

**Branch**: `012-diagnostics` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)

## Summary

Three diagnostic surfaces: `dotfiles-doctor` shell function (install
health), `ZSH_PROFILE=1` (zprof startup analysis), and structured
colored install logging (`bootstrap/logging.sh`). All read-only, all
graceful when their dependencies are missing.

## Technical Context

| Field             | Value                                          |
|-------------------|------------------------------------------------|
| Language/Version  | Bash; zsh's `zprof`                            |
| Dependencies      | tput (color detection); zprof (zsh-only)       |
| Storage           | n/a (read-only diagnostics)                    |
| Testing           | `tests/test-functions.sh`; CI startup-time logs |
| Target Platform   | All                                            |
| Project Type      | Single Project                                 |
| Performance Goals | dotfiles-doctor < 1s; logging overhead < 5ms   |
| Constraints       | Must work without color when stdout not TTY    |
| Scale/Scope       | 1 doctor function, ~25 checks; 5 log levels    |

## Constitution Check

| Article                            | Status | Notes                                                                       |
|------------------------------------|--------|------------------------------------------------------------------------------|
| I. Developer-Specific              | PASS   | Universal diagnostic surface.                                                |
| II. Defense-in-Depth Security      | PASS   | Doctor is read-only; no telemetry, no network calls.                         |
| III. Cross-Platform Parity         | PASS   | Logging works on TTY-less CI; doctor adapts to missing tools.                |
| IV. Idempotent and Reversible      | PASS   | Read-only by design.                                                         |
| V. Opt-In for High-Risk Surface    | PASS   | ZSH_PROFILE=1 is opt-in (not on by default).                                 |

## Project Structure

```
shell/functions.sh           # dotfiles-doctor function
shell/.zshrc                 # ZSH_PROFILE wiring
bootstrap/logging.sh         # log_* functions
```

### Structure Decision

Single Project. Diagnostics are co-located with the code they
diagnose; no separate diagnostic binary.

## Complexity Tracking

(empty)
