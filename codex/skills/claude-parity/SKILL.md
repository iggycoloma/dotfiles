---
name: claude-parity
description: Claude Code parity workflows for Codex CLI. Use when users ask for slash-command style tasks like context-prime, commit, pr-create, review-pr, debug, test, dependencies, security-audit, feature-spec, or pipeline.
metadata:
  short-description: Claude-style workflow playbooks
---

# Claude Parity

This skill mirrors the existing Claude Code command workflow style inside Codex.

## When to Use

Use this skill when:

- The user explicitly references Claude Code workflows or slash commands.
- The user asks for one-shot operational tasks (`commit`, `pr-create`, `review-pr`, `security-audit`, etc.).
- The user wants staged delivery flow (`pipeline`).

## How to Run This Skill

1. Map user intent to a command flow using `references/command-mapping.md`.
2. Execute the flow directly (do not ask for unnecessary confirmation).
3. Keep output practical: findings first, then actions taken, then next steps.
4. Apply guardrails from `~/.codex/AGENTS.md` or repo `AGENTS.md`.

## Pipeline Mode

For feature pipeline requests, follow `references/pipeline.md` exactly and pause between stages.

## Output Standards

- `review` output: every finding labelled blocking or non-blocking -- no third, softer tier -- with concrete file references, closing with the best available change.
- `commit` output: final message before commit action.
- `pr-create` output: title, summary bullets, testing notes, breaking changes, linked issues.
- `debug` output: evidence, root cause, fix, regression test.
