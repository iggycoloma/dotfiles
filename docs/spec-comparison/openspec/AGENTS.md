# Instructions for AI Agents

> Auto-maintained by `openspec update`. Do not edit manually -- add instructions
> via `config.yaml` instead. (For this comparison repository the file is hand-
> authored, but the shape mirrors what `openspec update` would produce.)

You are an AI assistant helping develop the dotfiles repository.
Read `project.md` for the worldview before authoring any artifact.

## Project Overview

Portable dotfiles that install a productive agentic coding environment on local hosts (macOS/Linux), VS Code devcontainers, and GitHub Codespaces.
Single `install.sh` detects the environment and adapts.
Safe to re-run.

The repo is **developer-specific**, not project-specific.
It installs universally useful CLI tools (rg, fd, bat, fzf, etc.) and deeply integrates agentic coding tools (Claude Code, Codex CLI).
For project-dependent tools (gh, docker, kubectl), it supplies *configuration surface* (aliases, completions, state persistence) but does not install them.
Projects bring their own tooling.

## Key Conventions

- Conventional commits, no AI attribution, no decorative emoji.
  Enforced by hooks; do not bypass with `--no-verify`.
- Shell scripts are POSIX-compatible bash with `set -euo pipefail`. shellcheck-clean before merge.
- Never read `.env`, credentials, secrets, `.pem`, `.key` files.
  Never access `~/.ssh/`, `~/.aws/`, `~/.gnupg/`, `~/.config/gh/`, `~/.dotfiles-state/`, or ~30 other credential paths.
  The `pre-security.sh` hook will block you anyway.
- Prefer `rg` over `grep`, `fd` over `find`, `sg` for structural code search, `difft` for diffs that ignore formatting noise.
  `jq` over manual JSON parsing, `yq` over manual YAML editing.
- No new MCP servers without explicit user request.
- No backwards-compat shims when removing code.
  The git history is the audit trail.

## OpenSpec Workflow

When you author a change, follow the artifact dependency chain:

1. `proposal.md` -- Intent, Scope, Approach, Impact, Acceptance Criteria.
   Captures *why* and *what* before *how*.
2. `design.md` -- Architecture, Key Decisions (chosen + reason + trade-off), Implementation Strategy, Testing Strategy.
   Captures *how*.
3. `tasks.md` -- numbered checklist (1.1, 1.2, ...) grouped by phase.
4. `specs/<capability>/spec.md` -- delta with `## ADDED Requirements`, `## MODIFIED Requirements`, `## REMOVED Requirements` sections.

Specs are *behavior contracts*, not implementation plans.
Use modal verbs (MUST / SHOULD / MUST NOT) for requirements.
Use GIVEN / WHEN / THEN for scenarios.
The implementation lives in code; the spec describes observable behavior.

When the change is archived (`/opsx:archive <name>`), the delta merges into `openspec/specs/` and the change folder moves to `openspec/changes/archive/<date>-<name>/`.

## Per-Artifact Rules

### Proposals
- Keep scope to a single coherent feature or change.
- Spell out *why now* -- what triggered the work, what the user/system pain is.
- List acceptance criteria the human can use to decide "is this done."

### Specs
- Group requirements by sub-area (`### Environment Detection`, `### Symlink Creation`, etc.).
- Modal verbs only: MUST, SHOULD, MUST NOT, SHOULD NOT, MAY.
- Every non-trivial requirement should have at least one scenario somewhere in the doc.
- Write a `## Non-Behavior` section listing the things the system explicitly does NOT do.
  This is where scope decisions get recorded.

### Designs
- For each Key Decision: chosen approach, the *why*, and the trade-off accepted.
  Include alternatives considered and rejected, with reasons.
- Reference the actual files (`bootstrap/detect.sh:42`, `claude-code/hooks/pre-security.sh`) -- not abstract layers.

### Tasks
- Number tasks `1.1, 1.2, 1.3, 2.1, ...` -- the first digit groups by phase or section, the second is the subtask.
  Mark each `- [ ]` so they can be checked off during `/opsx:apply`.
- Include verification subtasks: "1.5 Run `make lint` and confirm clean"; "3.4 Add test case to `tests/test-functions.sh` covering the new alias".
- A reasonable task is 30 minutes to 2 hours of work.
  If it's bigger, break it down.

## How to Respond

- When asked to generate an artifact, follow the template structure exactly.
- Use the instructions in any `<openspec-instructions>` block.
- When uncertain about scope or behavior, ask -- do not assume.
  The cost of a clarifying question is far less than the cost of a wrong delta spec being archived.
- Reference real code paths from `project.md`'s domain knowledge section.
  Do not invent file paths or behavior the repo does not actually have.
