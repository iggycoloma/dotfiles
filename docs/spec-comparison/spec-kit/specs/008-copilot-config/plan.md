# Implementation Plan: Copilot CLI Configuration

**Branch**: `008-copilot-config` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)

## Summary

Minimal Copilot CLI guardrail surface: one `copilot-instructions.md` mirroring Claude / Codex deny lists and preferred tools.
Stomp on devcontainers, symlink on hosts.
Honors `DOTFILES_NO_AI_TOOLS=1`.

## Technical Context

| Field             | Value                                            |
|-------------------|--------------------------------------------------|
| Language/Version  | Markdown                                         |
| Dependencies      | Copilot CLI (deployed by 002 if available)       |
| Storage           | `~/.copilot/`                                    |
| Testing           | `tests/test-consistency.sh`                      |
| Target Platform   | All                                              |
| Project Type      | Single Project                                   |
| Performance Goals | n/a                                              |
| Constraints       | Copilot's hook/skill system not yet exercised   |
| Scale/Scope       | 1 markdown file + 1 hooks.json                   |

## Constitution Check

| Article                            | Status | Notes                                                                       |
|------------------------------------|--------|------------------------------------------------------------------------------|
| I. Developer-Specific              | PASS   | Universal Copilot config.                                                    |
| II. Defense-in-Depth Security      | PASS   | Same instruction-text caveat as Codex (no runtime hooks).                    |
| III. Cross-Platform Parity         | PASS   | All matrix cells.                                                            |
| IV. Idempotent and Reversible      | PASS   | Stomp/symlink branching; `DOTFILES_NO_AI_TOOLS=1` honored.                  |
| V. Opt-In for High-Risk Surface    | PASS   | MCP off by default.                                                          |

## Project Structure

```
copilot/
|-- copilot-instructions.md
+-- hooks.json
```

### Structure Decision

Single Project.
One file + one config; no skills directory yet.

## Complexity Tracking

(empty)
