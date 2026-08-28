# Implementation Plan: Claude Code Configuration

**Branch**: `006-claude-code-config` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)

## Summary

Global Claude Code config deployed to `~/.claude/`.
Two-layer permission model (settings.json deny globs + pre-security.sh hook) plus the OS-level Claude Code sandbox on hosts (bwrap / seatbelt). 5 hooks, 5 agents, 16 slash commands, status line, CLAUDE.md.
Two settings variants -- host (`settings.json`, sandbox on) vs. container (`settings.container.json`, sandbox off) -- picked at install time by `_deploy_variant_file`.
Devcontainers force-copy on every boot; hosts get directory symlinks for live edits.
Migrates legacy `~/.claude.json` to `~/.claude/config.json`.
Hook contract is JSON-on-stdin / JSON-on-stdout per Claude Code's documented PreToolUse / PostToolUse / Notification / SessionStart events.

## Technical Context

| Field             | Value                                                                                |
|-------------------|--------------------------------------------------------------------------------------|
| Language/Version  | Bash for hooks; JSON for settings; Markdown for agents/commands/CLAUDE.md            |
| Dependencies      | jq (mandatory in every hook); perl (for emoji regex); claude CLI (deployed by 002); on Linux hosts, bubblewrap + socat (paired) |
| Storage           | `~/.claude/` (volume-backed in devcontainers via 009)                                |
| Testing           | `tests/test-security-hook.sh`; `tests/test-consistency.sh`; `tests/test-drift.sh`    |
| Target Platform   | All; hooks run on bash 3.2+ (macOS compatibility); host sandbox bwrap (Linux/WSL2) and seatbelt (macOS) |
| Project Type      | Single Project                                                                       |
| Performance Goals | Hook overhead < 50ms per Read/Write; SessionStart banner < 100ms                     |
| Constraints       | Hook contract version-locked to current Claude Code; jq required; sandbox.enabled gated by environment |
| Scale/Scope       | 5 hooks, 5 agents, 16 commands, ~70 Bash allows, ~35 credential deny globs, ~20 Bash deny patterns, 2 settings variants |

## Constitution Check

| Article                            | Status | Notes                                                                       |
|------------------------------------|--------|------------------------------------------------------------------------------|
| I. Developer-Specific              | PASS   | Universal Claude config; project-specific guardrails belong in per-repo CLAUDE.md. |
| II. Three-Tier Defense             | PASS   | Tier 1 (deny globs + pre-security.sh substring scan) is in this capability. Tier 2 (sandbox/sudo gate) is deferred to the OS sandbox or container boundary. Tier 3 (branch protection) is deferred to GitHub. |
| III. Cross-Platform Parity         | PASS   | Hooks run on bash 3.2; tested on macOS and Linux. Sandbox is bwrap on Linux/WSL2, seatbelt on macOS, off in containers. |
| IV. Idempotent and Reversible      | PASS   | Stomp-copy on devcontainers; symlinks on hosts; migration of legacy config.json. Variant picker is idempotent. |
| V. Opt-In for High-Risk Surface    | PASS   | MCP servers explicitly NOT installed by default.                            |

## Project Structure

```
claude-code/
|-- CLAUDE.md
|-- settings.json                  Host variant: sandbox.enabled: true
|-- settings.container.json        Container variant: sandbox.enabled: false
|-- statusline.sh
|-- hooks/
|   |-- pre-security.sh
|   |-- pre-code-no-emoji.sh
|   |-- post-scope-audit.sh
|   |-- post-dep-audit.sh
|   |-- notify.sh
|   +-- session-start-banner.sh
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

Single Project.
Hooks, agents, and commands are flat directories with one file per entity.
Shared regex/utility logic lives under the repo-level `agent-hooks/lib/` and is sourced by hooks across capabilities.
The two `settings*.json` files MUST stay in lockstep except for the sandbox block; `bin/settings-drift.sh` enforces this.

## Complexity Tracking

| Violation                                                              | Why Needed                                                                                                                  | Simpler Alternative Rejected Because                                                                          |
|------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| Two-layer Tier 1 security (settings deny rules + pre-security.sh)      | Settings glob matching is exact; the hook scans full Bash command strings, catching `cat ../some/path/.env` that globs can't. | One-layer (globs only) misses Bash-string credential references; one-layer (hooks only) is bypassable when the hook fails. |
| Two settings variants (host + container)                               | The host sandbox (bwrap/seatbelt) and the container boundary are different trust roots. A single settings file would either over-restrict containers (legitimate work blocked) or under-protect hosts (no sandbox). | One file with environment-conditional sandbox values is what we tried first; Claude Code's settings loader does not evaluate conditionals at read time, so the variants must be separate files chosen by the installer. |
| `bin/settings-drift.sh` as a separate lint                             | Variants drift silently when contributors edit one and not the other. The linter catches this before merge.                  | Manual review is the historical method; it doesn't scale and missed an asymmetric edit in PR #54.             |
| Three-tier responsibility model                                        | Defending each risk at the right layer (file content, system, remote) prevents redundant prompts and false confidence (e.g. trying to block `git push main` locally when only branch protection actually defends trunk). | Mixing tiers in the Bash deny list produced confusing UX (sudo-gated commands prompted repeatedly even though sudo is already blocked); explicit tier ownership is cleaner. |
