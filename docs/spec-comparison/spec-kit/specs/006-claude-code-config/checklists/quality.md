# Checklist: Quality - Claude Code Configuration

**Purpose**: Pre-merge gate for changes to `claude-code/`. Run before
asking for review.

**Feature**: 006-claude-code-config
**Date created**: 2026-04-01
**Links**: [spec.md](../spec.md), [plan.md](../plan.md),
          [tasks.md](../tasks.md), [hook-protocol contract](../contracts/hook-protocol.md)

## Category 1: Permission rule consistency

- [ ] CHK001 New deny pattern in settings.json also added to
       claude-code/CLAUDE.md guardrails section.
- [ ] CHK002 New deny pattern also added to codex/AGENTS.md and
       copilot/copilot-instructions.md.
- [ ] CHK003 New deny pattern verified against `pre-security.sh`
       SENSITIVE_PATHS / SENSITIVE_DIRS / SENSITIVE_FILES (no gap
       between layers).
- [ ] CHK004 `tests/test-consistency.sh` expanded to cover the new
       pattern.

## Category 2: Hook robustness

- [ ] CHK005 New hook (or modified hook) handles the case where `jq`
       is missing (clean error, not silent corruption).
- [ ] CHK006 New hook returns valid JSON on stdout (validated with
       `jq empty`).
- [ ] CHK007 New hook never sends data to a network endpoint without
       env-var gating.
- [ ] CHK008 New hook completes in < 50ms on typical input.
- [ ] CHK009 New hook tested with at least 5 cases in
       `tests/test-security-hook.sh`.

## Category 3: Agent and command additions

- [ ] CHK010 New agent declares its tool allowlist in frontmatter; no
       broader than necessary.
- [ ] CHK011 New command documents its arguments and side effects.
- [ ] CHK012 New command does not invoke `--no-verify`, `git push
       --force`, `git reset --hard`, or other destructive operations
       without explicit user confirmation.
- [ ] CHK013 New command, if it spawns sub-agents, includes user
       checkpoints between stages where state-changing work happens.

## Category 4: Cross-platform

- [ ] CHK014 New shell script uses bash 3.2-compatible syntax (no
       associative arrays, no `${var,,}`, careful regex).
- [ ] CHK015 Tested on both macOS and Linux CI matrix cells.
- [ ] CHK016 Hook works when invoked from the global hook path
       (delegated invocation).

## Category 5: Documentation

- [ ] CHK017 README.md "Agentic Coding Tools" section updated if a
       user-visible behavior changes.
- [ ] CHK018 spec.md updated if a new requirement (FR-###) is
       introduced.
- [ ] CHK019 plan.md Constitution Check re-validated; if a new
       violation is introduced, Complexity Tracking has an entry.

## Notes

- Use `[X]` to mark complete; `[!]` to mark "intentionally skipped"
  with a one-line note inline.
- This checklist is consumed by `/implement` -- if any item is `[ ]`
  when `/implement` runs, the command halts.
- Numbering is sequential (CHK001..CHK019); don't renumber when adding
  -- append new items at the bottom of the relevant category.
