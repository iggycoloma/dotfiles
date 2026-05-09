# Feature Specification: Claude Code Configuration

**Branch**: `006-claude-code-config` | **Date**: 2026-04-01 | **Status**: Implemented

## User Scenarios & Testing

### User Story 1 - Safe by default in any repo (Priority: P1)

A developer uses Claude Code in any repository on their machine.
Credential paths are blocked, conventional commits are enforced, and
Claude can't accidentally read secrets, even on first use.

**Why this priority**: This is the primary safety promise of the
deployment. Without it, every project would need its own deny rules.

**Independent Test**: Spin up Claude Code in a fresh repo (no
project-level config), have it attempt `Read(.env)`. Assert the call is
denied by the framework before any hook runs.

**Acceptance Scenarios**:
```
GIVEN Claude Code is configured with the deployed settings.json
WHEN Claude attempts Read(file_path: "/workspaces/foo/.env")
THEN the Read(**/.env) deny rule matches
  AND the call is rejected before pre-security.sh runs
  AND Claude receives the standard "permission denied" tool error
```

```
GIVEN Claude Code attempts Bash(command: "ls ~/.ssh/")
WHEN pre-security.sh runs as the PreToolUse hook
THEN it detects ".ssh/" in the command string
  AND emits {permissionDecision: "ask", permissionDecisionReason: "..."}
  AND the user gets a prompt before execution
```

### User Story 2 - 4-stage pipeline orchestration (Priority: P1)

A developer wants to drive a feature end-to-end: PM spec, architecture
review, implementation with tests, QA review. Each stage is a
constrained sub-agent; user checkpoints between stages.

**Independent Test**: Run `/pipeline add login feature`, assert
`pm-spec` agent is spawned with Read/Grep/Write only, then user
checkpoint, then `architect-review`, etc.

**Acceptance Scenarios**:
```
GIVEN the user types `/pipeline add login feature`
WHEN the command runs
THEN Claude spawns pm-spec (Read/Grep/Write tools only)
  AND pauses for user review of the spec
  AND continues with architect-review (Read/Grep/Glob)
  AND pauses for user review of the ADR
  AND continues with implementer-tester (Read/Write/Edit/Bash)
  AND finishes with qa-reviewer (Read/Bash/Grep/Glob)
```

### User Story 3 - SessionStart guardrail reminder (Priority: P2)

Every Claude Code session starts with a system reminder about no-emoji,
conventional commits, credential deny lists, and preferred CLI tools.

**Independent Test**: Start a new Claude Code session, assert the
SessionStart hook output contains the guardrail reminder.

**Acceptance Scenarios**:
```
GIVEN a new Claude Code session begins in any repo
WHEN the SessionStart hook fires
THEN session-start-banner.sh emits a system reminder
  AND the reminder mentions no-emoji and conventional commits
  AND the reminder mentions preferred CLI tools (sg, difft, sd, scc, yq)
```

### User Story 4 - Idle Pushover notification (Priority: P3)

A developer running Claude Code on a long task wants a phone
notification when Claude finishes a step and is waiting for input.

**Independent Test**: Set `PUSHOVER_TOKEN` and `PUSHOVER_USER`, run a
Claude task that pauses for input, assert a Pushover notification
arrives.

**Acceptance Scenarios**:
```
GIVEN PUSHOVER_TOKEN and PUSHOVER_USER are set
  AND Claude Code finishes a step and waits for user input
WHEN the Notification hook fires on idle_prompt
THEN notify.sh sends a Pushover notification
  AND the notification reaches the user's phone within 5 seconds
```

### Edge Cases

- **MCP server present in `.mcp.json`**: deny rules do NOT apply to MCP
  child processes. The CLAUDE.md guidance flags this; the user must
  audit MCP servers themselves.
- **No `PUSHOVER_TOKEN` set**: notify.sh silent no-op.
- **Custom project `CLAUDE.md`**: project-level instructions override
  global ones (per Claude Code's hierarchy).
- **Hook script missing `jq`**: hook errors out with stderr message;
  framework falls back to default behavior (no permission decision).

## Requirements

### Functional Requirements

- **FR-001** Installer MUST deploy `settings.json`, `CLAUDE.md`,
  `statusline.sh`, `hooks/`, `agents/`, `commands/` from
  `claude-code/` to `~/.claude/`.
- **FR-002** In devcontainers, deployment MUST be force-copy (stomp)
  every boot.
- **FR-003** On hosts, directories MUST be symlinked, individual files
  MUST be copied.
- **FR-004** Installer MUST migrate `~/.claude.json` to
  `~/.claude/config.json` if the legacy file exists and the new path
  does not.
- **FR-005** Deployed `settings.json` MUST contain ~70 Bash allow
  entries and ~35 credential deny globs (Read/Write/Edit) plus
  destructive Bash deny patterns.
- **FR-006** Deployed `settings.json` MUST register PreToolUse hooks:
  `pre-security.sh` for Read/Write/Edit and Bash;
  `pre-commit-validate.sh` for Bash with `if: Bash(git commit*)`;
  `pre-code-no-emoji.sh` for Write/Edit.
- **FR-007** Deployed `settings.json` MUST register PostToolUse hooks:
  `post-scope-audit.sh` for Write/Edit; `post-dep-audit.sh` for Bash
  (60s timeout).
- **FR-008** Deployed `settings.json` MUST register Notification hook
  on `idle_prompt` -> `notify.sh`.
- **FR-009** Deployed `settings.json` MUST register SessionStart hook
  -> `session-start-banner.sh`.
- **FR-010** `pre-security.sh` MUST scan file_path (Read/Write/Edit)
  and command string (Bash) against sensitive paths/dirs/files; MUST
  return `ask` for matches and `deny` for path traversal.
- **FR-011** `pre-commit-validate.sh` MUST mirror commit-msg hook
  rules (conv-commits, no AI attribution, no emoji) at the Claude
  proposal layer.
- **FR-012** `pre-code-no-emoji.sh` MUST detect Unicode emoji ranges
  in proposed Write/Edit content and block.
- **FR-013** Installer MUST ship 5 sub-agents under `claude-code/agents/`:
  pm-spec, architect-review, implementer-tester, qa-reviewer,
  code-reviewer.
- **FR-014** Installer MUST ship at least 16 slash commands.
- **FR-015** `/pipeline` command MUST orchestrate the 4-stage flow with
  user checkpoints.
- **FR-016** `statusline.sh` MUST display git branch, working tree
  status, context-usage bar, and active model.

### Key Entities

- **Tool call event**: `{tool_name, tool_input}` -- piped to hooks via
  stdin as JSON.
- **Permission decision**: `{permissionDecision: "allow" | "ask" |
  "deny", permissionDecisionReason: string}`.
- **Sub-agent**: markdown file with frontmatter declaring tool
  allowlist + behavior instructions.

## Success Criteria

- **SC-001** 100% of `.env*` Read attempts denied by framework rules
  (no hook reliance).
- **SC-002** test-security-hook.sh covers all 35+ deny patterns.
- **SC-003** Pipeline command runs to completion in CI integration
  test.
- **SC-004** SessionStart banner emits in every new session (verified
  via test).
- **SC-005** Per-boot config refresh: stale `settings.json` from
  previous container is replaced within the install run.

## Assumptions

- Claude Code's hook contract remains stable
  (`{hookSpecificOutput: {...}}` JSON shape).
- `jq` is available in every environment (it's a core tool, installed
  by `002-packages`).
- Users do not edit `~/.claude/settings.json` directly; they use
  `~/.claude/settings.local.json` for per-machine overrides.
- The `4-stage pipeline` ordering (PM -> Architect -> Implementer ->
  QA) reflects how the developer actually wants to drive features.
