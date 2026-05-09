# Implementation Plan: Claude Code Configuration

**Branch**: `006-claude-code-config` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)

## Summary

Global Claude Code config deployed to `~/.claude/`. Two-layer permission
model (settings.json deny globs + pre-security.sh hook). 6 hooks, 5 agents,
16 slash commands, status line, CLAUDE.md. Devcontainers force-copy on every
boot; hosts get directory symlinks for live edits. Migrates legacy
`~/.claude.json` to `~/.claude/config.json`. Hook contract is JSON-on-stdin /
JSON-on-stdout per Claude Code's documented PreToolUse / PostToolUse /
Notification / SessionStart events.

## Technical Context

| Field             | Value                                                                                |
|-------------------|--------------------------------------------------------------------------------------|
| Language/Version  | Bash for hooks; JSON for settings; Markdown for agents/commands/CLAUDE.md            |
| Dependencies      | jq (mandatory in every hook); perl (for emoji regex); claude CLI (deployed by 002)   |
| Storage           | `~/.claude/` (volume-backed in devcontainers via 009)                                |
| Testing           | `tests/test-security-hook.sh`; `tests/test-consistency.sh`                           |
| Target Platform   | All; hooks run on bash 3.2+ (macOS compatibility)                                    |
| Project Type      | Single Project                                                                       |
| Performance Goals | Hook overhead < 50ms per Read/Write; SessionStart banner < 100ms                     |
| Constraints       | Hook contract version-locked to current Claude Code; jq required                     |
| Scale/Scope       | 6 hooks, 5 agents, 16 commands, ~70 Bash allows, ~35 deny globs                      |

## Constitution Check

| Article                            | Status | Notes                                                                       |
|------------------------------------|--------|------------------------------------------------------------------------------|
| I. Developer-Specific              | PASS   | Universal Claude config; project-specific guardrails belong in per-repo CLAUDE.md. |
| II. Defense-in-Depth Security      | PASS   | Layer 1 of defense-in-depth: deny globs + hooks complementary, not redundant. |
| III. Cross-Platform Parity         | PASS   | Hooks run on bash 3.2; tested on macOS and Linux.                           |
| IV. Idempotent and Reversible      | PASS   | Stomp-copy on devcontainers; symlinks on hosts; migration of legacy config.json. |
| V. Opt-In for High-Risk Surface    | PASS   | MCP servers explicitly NOT installed by default.                            |

## Project Structure

```
claude-code/
|-- CLAUDE.md
|-- settings.json
|-- statusline.sh
|-- hooks/
|   |-- pre-security.sh
|   |-- pre-commit-validate.sh
|   |-- pre-code-no-emoji.sh
|   |-- post-scope-audit.sh
|   |-- post-dep-audit.sh
|   |-- notify.sh
|   |-- session-start-banner.sh
|   +-- shared-patterns.sh
|-- agents/
|   |-- pm-spec.md
|   |-- architect-review.md
|   |-- implementer-tester.md
|   |-- qa-reviewer.md
|   +-- code-reviewer.md
+-- commands/
    |-- commit.md, pr-create.md, review-pr.md, security-audit.md,
    |-- pipeline.md, feature-spec.md, debug.md, test.md, optimize.md,
    +-- dependencies.md, refactor.md, deploy-checklist.md, docs.md,
        changelog.md, fix-issue.md, context-prime.md
```

### Structure Decision

Single Project. Hooks, agents, and commands are flat directories with one
file per entity. The shared `shared-patterns.sh` lives under hooks/ but is
sourced by both `pre-commit-validate.sh` AND `git/hooks/commit-msg` (cross-
capability dependency intentional).

## Complexity Tracking

| Violation                                                              | Why Needed                                                                                                                  | Simpler Alternative Rejected Because                                                                          |
|------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| Two-layer security (settings deny rules + pre-security.sh hook)        | Settings glob matching is exact; hook scans full Bash command strings catching `cat ../some/path/.env` that globs can't.    | One-layer (globs only) misses Bash-string credential references; one-layer (hooks only) is bypassable when hook fails. |
| `shared-patterns.sh` cross-cap dependency to git/hooks                 | The same regex catalog must apply at the Claude proposal layer AND at the git commit layer. Sharing prevents drift.         | Two copies of the regex would inevitably diverge silently.                                                    |
