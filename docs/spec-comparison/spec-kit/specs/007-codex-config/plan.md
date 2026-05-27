# Implementation Plan: Codex CLI Configuration

**Branch**: `007-codex-config` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)

## Summary

Mirror Claude Code's guardrails in Codex CLI. Deploy AGENTS.md (deny
lists, preferred tools, MCP posture), claude-parity skill set
(equivalent workflows for commit / pr-create / review / debug /
pipeline), and a Pushover idle-notify hook. Deploy a host vs container
variant pair for `config.toml`: hosts symlink the `workspace-write`
variant (and preserve user edits); devcontainers copy the
`danger-full-access` variant fresh on every install.

## Technical Context

| Field             | Value                                        |
|-------------------|----------------------------------------------|
| Language/Version  | Bash for hooks; Markdown for skills + AGENTS |
| Dependencies      | codex CLI (deployed by 002), curl (notify)   |
| Storage           | `~/.codex/` (volume-backed in devcontainers) |
| Testing           | `tests/test-consistency.sh`                  |
| Target Platform   | All                                          |
| Project Type      | Single Project                               |
| Performance Goals | Skill resolution < 100ms                     |
| Constraints       | Codex hook system more limited than Claude's; AGENTS.md is the primary guardrail |
| Scale/Scope       | 1 skill pack, 1 hook, 1 AGENTS.md            |

## Constitution Check

| Article                            | Status | Notes                                                                       |
|------------------------------------|--------|------------------------------------------------------------------------------|
| I. Developer-Specific              | PASS   | Universal Codex config.                                                      |
| II. Defense-in-Depth Security      | PASS   | Codex layer relies on AGENTS.md instructions (no runtime hooks like Claude); accepted limitation. |
| III. Cross-Platform Parity         | PASS   | All matrix cells.                                                            |
| IV. Idempotent and Reversible      | PASS   | Stomp on devcontainers; per-skill copy on hosts; config.toml preserved.      |
| V. Opt-In for High-Risk Surface    | PASS   | MCP off by default.                                                          |

## Project Structure

```
codex/
|-- AGENTS.md
|-- config.toml                  # host variant (sandbox_mode = "workspace-write")
|-- config.container.toml        # container variant (sandbox_mode = "danger-full-access")
|-- hooks.json
|-- hooks/notify.sh
+-- skills/claude-parity/
    |-- context-prime.md, commit.md, pr-create.md, review-pr.md,
    +-- debug.md, test.md, dependencies.md, security-audit.md,
        feature-spec.md, pipeline.md
```

### Structure Decision

Single Project. One skill pack (`claude-parity`) keeps the surface
minimal; additional skill packs would each get their own subdirectory.

## Complexity Tracking

| Violation                                        | Why Needed                                                                       | Simpler Alternative Rejected Because                                  |
|--------------------------------------------------|----------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| Codex security relies on AGENTS.md instruction text rather than runtime hooks | Codex's hook surface is too limited to enforce credential blocking the way Claude's PreToolUse hook does. | Doing nothing leaves Codex with no guardrails at all; better an instruction-text contract than nothing. |
