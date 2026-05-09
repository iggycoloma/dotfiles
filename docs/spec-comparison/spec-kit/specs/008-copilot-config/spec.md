# Feature Specification: Copilot CLI Configuration

**Branch**: `008-copilot-config` | **Date**: 2026-04-01 | **Status**: Implemented

## User Scenarios & Testing

### User Story 1 - Aligned guardrails for Copilot (Priority: P1)

A developer using Copilot CLI in any repo gets the same credential
deny lists, no-emoji rule, and conventional-commit expectation that
Claude Code and Codex enforce.

**Independent Test**: After install, assert
`~/.copilot/copilot-instructions.md` exists and lists the same
credential paths as `~/.claude/CLAUDE.md`.

**Acceptance Scenarios**:
```
GIVEN ./install.sh ran
WHEN Copilot CLI starts in any repo
THEN ~/.copilot/copilot-instructions.md is loaded
  AND it lists the same credential deny patterns as Claude/Codex
  AND it lists preferred CLI tools (rg, sg, fd, difft, sd, bat)
  AND it forbids new MCP servers without user request
```

### User Story 2 - Devcontainer rebuild refresh (Priority: P2)

In devcontainers, every rebuild gets the current dotfiles version of
copilot-instructions.md (force-copy semantics, like Claude/Codex).

**Acceptance Scenarios**:
```
GIVEN a devcontainer with stale ~/.copilot/copilot-instructions.md
WHEN the container rebuilds and ./install.sh runs
THEN the file is replaced with the current dotfiles version
  AND any local edits in the previous container are lost (intentional)
```

### Edge Cases

- **`DOTFILES_NO_AI_TOOLS=1`**: Copilot config skipped entirely.
- **`~/.copilot` already a directory** (Copilot CLI auto-created): the
  install handles the existing directory cleanly.

## Requirements

### Functional Requirements

- **FR-001** Installer MUST deploy `copilot-instructions.md` and
  `hooks.json` from `copilot/` to `~/.copilot/`.
- **FR-002** In devcontainers, deployment MUST be force-copy.
- **FR-003** On hosts, deployment MUST be via symlink.
- **FR-004** `DOTFILES_NO_AI_TOOLS=1` MUST skip Copilot config
  deployment.
- **FR-005** Deployed `copilot-instructions.md` MUST list the same
  ~50 credential patterns as Claude/Codex.
- **FR-006** Deployed file MUST list preferred CLI tools.
- **FR-007** Deployed file MUST forbid `../` path traversal.
- **FR-008** Deployed file MUST forbid decorative emoji.
- **FR-009** Deployed file MUST forbid AI attribution and
  Co-Authored-By.
- **FR-010** Deployed file MUST forbid installing new MCP servers.
- **FR-011** `~/.copilot` MUST appear in the credential deny lists
  of Claude Code, Codex, and the global git hooks (Copilot stores
  session tokens there).

### Key Entities

- **Instructions file**: single Markdown file consumed by Copilot CLI
  on startup.

## Success Criteria

- **SC-001** test-consistency.sh passes: deny-list parity across
  Claude / Codex / Copilot.
- **SC-002** Devcontainer rebuild test: stale file is replaced.
- **SC-003** Host symlink test: edit in repo immediately visible to
  Copilot.

## Assumptions

- Copilot CLI's instruction-loading path is `~/.copilot/copilot-
  instructions.md`.
- Copilot CLI's hook system is accepted-as-is (no custom hooks
  beyond the upstream-required `hooks.json`).
- Future Copilot CLI features (skills, slash commands) will be added
  by separate specs.
