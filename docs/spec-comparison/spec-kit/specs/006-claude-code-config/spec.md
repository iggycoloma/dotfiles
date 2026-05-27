# Feature Specification: Claude Code Configuration

**Branch**: `006-claude-code-config` | **Date**: 2026-04-01 | **Status**: Implemented

## User Scenarios & Testing

### User Story 1 - Safe by default in any repo (Priority: P1)

A developer uses Claude Code in any repository on their machine.
Credential paths are blocked, conventional commits are enforced, and Claude can't accidentally read secrets, even on first use.

**Why this priority**: This is the primary safety promise of the deployment.
Without it, every project would need its own deny rules.

**Independent Test**: Spin up Claude Code in a fresh repo (no project-level config), have it attempt `Read(.env)`.
Assert the call is denied by the framework before any hook runs.

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

A developer wants to drive a feature end-to-end: PM spec, architecture review, implementation with tests, QA review.
Each stage is a constrained sub-agent; user checkpoints between stages.

**Independent Test**: Run `/pipeline add login feature`, assert `pm-spec` agent is spawned with Read/Grep/Write only, then user checkpoint, then `architect-review`, etc.

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

Every Claude Code session starts with a system reminder about no-emoji, conventional commits, credential deny lists, and preferred CLI tools.

**Independent Test**: Start a new Claude Code session, assert the SessionStart hook output contains the guardrail reminder.

**Acceptance Scenarios**:
```
GIVEN a new Claude Code session begins in any repo
WHEN the SessionStart hook fires
THEN session-start-banner.sh emits a system reminder
  AND the reminder mentions no-emoji and conventional commits
  AND the reminder mentions preferred CLI tools (sg, difft, sd, scc, yq)
```

### User Story 4 - Sandbox posture by environment (Priority: P1)

A developer running Claude Code on a host gets the OS-level Claude Code sandbox (bwrap on Linux/WSL2, seatbelt on macOS) with explicit egress allowlist.
The same developer in a devcontainer gets the sandbox turned off, because the container itself is the trust boundary; doubling sandboxes there blocks legitimate work without adding isolation.

**Why this priority**: Without environment-aware sandbox posture, the choice is between (a) a strict host-sandbox that breaks inside containers (cannot reach the container filesystem outside the workspace), or (b) no sandbox at all, which leaves hosts exposed.
Variant files solve this.

**Independent Test**: On a host, assert `~/.claude/settings.json` has `sandbox.enabled: true` and the ssh-agent socket is in `allowUnixSockets`.
In a devcontainer, assert `~/.claude/settings.json` has `sandbox.enabled: false`.

**Acceptance Scenarios**:
```
GIVEN a macOS or Linux host running ./install.sh
WHEN _deploy_variant_file runs for settings.json
THEN ~/.claude/settings.json symlinks to claude-code/settings.json
  AND that file sets sandbox.enabled: true
  AND lists the ssh-agent socket under allowUnixSockets
```

```
GIVEN a devcontainer (REMOTE_CONTAINERS=true) running ./install.sh
WHEN _deploy_variant_file runs for settings.json
THEN ~/.claude/settings.json is a copy of claude-code/settings.container.json
  AND that file sets sandbox.enabled: false
  AND the container boundary remains the trust root
```

### User Story 5 - Idle Pushover notification (Priority: P3)

A developer running Claude Code on a long task wants a phone notification when Claude finishes a step and is waiting for input.

**Independent Test**: Set `PUSHOVER_TOKEN` and `PUSHOVER_USER`, run a Claude task that pauses for input, assert a Pushover notification arrives.

**Acceptance Scenarios**:
```
GIVEN PUSHOVER_TOKEN and PUSHOVER_USER are set
  AND Claude Code finishes a step and waits for user input
WHEN the Notification hook fires on idle_prompt
THEN notify.sh sends a Pushover notification
  AND the notification reaches the user's phone within 5 seconds
```

### Edge Cases

- **MCP server present in `.mcp.json`**: deny rules do NOT apply to MCP child processes.
  The CLAUDE.md guidance flags this; the user must audit MCP servers themselves.
- **No `PUSHOVER_TOKEN` set**: notify.sh silent no-op.
- **Custom project `CLAUDE.md`**: project-level instructions override global ones (per Claude Code's hierarchy).
- **Hook script missing `jq`**: hook errors out with stderr message; framework falls back to default behavior (no permission decision).

## Requirements

### Functional Requirements

- **FR-001** Installer MUST deploy `CLAUDE.md`, `statusline.sh`, `hooks/`, `agents/`, `commands/` from `claude-code/` to `~/.claude/`, plus a `settings.json` chosen by environment (host variant vs. container variant).
- **FR-002** Installer MUST deploy `settings.json` via `_deploy_variant_file`: symlink `claude-code/settings.json` on hosts, copy `claude-code/settings.container.json` inside devcontainers.
  The container variant is copied so the dotfiles repo need not be present at runtime.
- **FR-003** Host variant (`settings.json`) MUST set `sandbox.enabled: true`, declare `sandbox.network.allowedDomains`, and include the ssh-agent socket in `sandbox.network.allowUnixSockets`.
- **FR-004** Container variant (`settings.container.json`) MUST set `sandbox.enabled: false`.
  The two variants MUST otherwise carry the same allow/deny lists and hook registrations; any other drift is a bug (caught by `bin/settings-drift.sh`).
- **FR-005** In devcontainers, deployment MUST be force-copy (stomp) every boot.
- **FR-006** On hosts, directories MUST be symlinked, individual files MUST be copied.
- **FR-007** Installer MUST migrate `~/.claude.json` to `~/.claude/config.json` if the legacy file exists and the new path does not.
- **FR-008** Deployed `settings.json` MUST contain ~70 Bash allow entries and ~35 credential deny globs (Read/Write/Edit) plus ~20 Bash deny patterns covering local-state footguns.
  The Bash deny list MUST NOT enumerate sudo-gated commands (iptables, systemctl, mkfs, dd, shutdown, etc.); those are blocked at a single upstream point by `sudo:*`.
  The Bash deny list MUST NOT attempt to enforce trunk protection (`git push * main*`); the glob-prefix matcher does not support inline wildcards reliably and GitHub branch protection is the authoritative defense.
- **FR-009** `git push --force-with-lease` MUST be allowed (safe for stacked-PR rebases; refuses to overwrite a ref that has moved since fetch).
  Plain `git push --force` and `git push -f` MUST be denied.
- **FR-010** Deployed `settings.json` MUST register 5 hooks: PreToolUse `pre-security.sh` for Read/Write/Edit and Bash; PreToolUse `pre-code-no-emoji.sh` for Write/Edit; PostToolUse `post-scope-audit.sh` for Write/Edit; PostToolUse `post-dep-audit.sh` for Bash (60s timeout); Notification `notify.sh` on `idle_prompt`; SessionStart `session-start-banner.sh`.
  (PreToolUse `pre-security.sh` on Bash and on Read/Write/Edit is one hook with two trigger sets, not two.) Commit-message validation MUST NOT be a PreToolUse hook; the prior `pre-commit-validate.sh` is deprecated.
  Conventional-commit enforcement lives in the global git `commit-msg` hook wired via `core.hooksPath`.
- **FR-011** `pre-security.sh` MUST scan file_path (Read/Write/Edit) and command string (Bash) against sensitive paths/dirs/files; MUST return `ask` for matches and `deny` for path traversal.
- **FR-012** `pre-code-no-emoji.sh` MUST detect Unicode emoji ranges in proposed Write/Edit content and block.
  The Claude plan and memory paths MUST be exempt (`~/.claude/projects/**/plan*.md`, `~/.claude/projects/**/memory/**`).
- **FR-013** Installer MUST ship 5 sub-agents under `claude-code/agents/`: pm-spec, architect-review, implementer-tester, qa-reviewer, code-reviewer.
- **FR-014** Installer MUST ship at least 16 slash commands.
- **FR-015** `/pipeline` command MUST orchestrate the 4-stage flow with user checkpoints.
- **FR-016** `statusline.sh` MUST display git branch, working tree status, context-usage bar, and active model.

### Three-tier responsibility model

- **FR-017** The Bash deny list MUST defend Tier 1 only -- local-state footguns where no other layer catches a typo.
  System-state defense (Tier 2) MUST defer to the OS sandbox (bwrap / seatbelt) on hosts and the container boundary in devcontainers, with `sudo:*` as the upstream gate.
  Remote / shared defense (Tier 3) MUST defer to GitHub branch protection on the server.
  The deny list MUST NOT duplicate Tier 2 or Tier 3 coverage.

### Key Entities

- **Tool call event**: `{tool_name, tool_input}` -- piped to hooks via stdin as JSON.
- **Permission decision**: `{permissionDecision: "allow" | "ask" | "deny", permissionDecisionReason: string}`.
- **Sub-agent**: markdown file with frontmatter declaring tool allowlist + behavior instructions.

## Success Criteria

- **SC-001** 100% of `.env*` Read attempts denied by framework rules (no hook reliance).
- **SC-002** test-security-hook.sh covers all 35+ deny patterns.
- **SC-003** Pipeline command runs to completion in CI integration test.
- **SC-004** SessionStart banner emits in every new session (verified via test).
- **SC-005** Per-boot config refresh: stale `settings.json` from previous container is replaced within the install run.

## Assumptions

- Claude Code's hook contract remains stable (`{hookSpecificOutput: {...}}` JSON shape).
- `jq` is available in every environment (it's a core tool, installed by `002-packages`).
- Users do not edit `~/.claude/settings.json` directly; they use `~/.claude/settings.local.json` for per-machine overrides.
- The `4-stage pipeline` ordering (PM -> Architect -> Implementer -> QA) reflects how the developer actually wants to drive features.
