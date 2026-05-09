# claude-code-config

## Overview

Global Claude Code configuration deployed to `~/.claude/`. Includes
permissions (allow/deny lists), 6 hooks, 5 sub-agents, 16 slash commands,
the status line, and the `CLAUDE.md` global instructions. Designed to make
Claude Code safe-by-default in any repo without per-project configuration.

## Requirements

### Deployment

- The installer MUST deploy `settings.json`, `CLAUDE.md`, `statusline.sh`,
  and the `hooks/`, `agents/`, `commands/` directories from
  `<DOTFILES_DIR>/claude-code/` into `~/.claude/`.
- In devcontainers, the installer MUST force-copy (stomp) every file every
  boot so the container always reflects the dotfiles version.
- On hosts, the installer MUST symlink directories (so live edits in the
  repo propagate) but MUST copy individual files (atomic writes break file
  symlinks).
- The installer MUST migrate `~/.claude.json` to `~/.claude/config.json` if
  the legacy file exists and the new path does not.

### settings.json: permissions

- The deployed `settings.json` MUST contain an `allow` list permitting
  ~70 Bash commands (git read commands, gh read commands, ls/find/grep,
  curl, etc.) and the Read/Glob/Grep/WebSearch/WebFetch tools.
- The deployed `settings.json` MUST contain a `deny` list with ~35
  credential glob patterns covering `.env*`, `**/credentials*`,
  `**/*secret*`, `**/*.pem`, `~/.ssh/**`, `~/.aws/**`, `~/.gnupg/**`,
  `~/.config/gh/**`, `~/.dotfiles-state/**`, etc., applied to
  Read/Write/Edit.
- The deployed `settings.json` MUST contain Bash deny patterns for
  destructive operations: `rm -rf`, `git reset --hard`, `git push --force`,
  `chmod -R 777`, `sudo:*`, `dd if=`, `mkfs:*`, `shutdown:*`, etc.

### settings.json: hooks

- `settings.json` MUST register PreToolUse hooks for Read/Write/Edit
  (running `pre-security.sh`) and for Bash (running `pre-security.sh` plus
  `pre-commit-validate.sh` conditionally on `git commit*`).
- `settings.json` MUST register a PreToolUse hook for Write/Edit running
  `pre-code-no-emoji.sh`.
- `settings.json` MUST register PostToolUse hooks for Write/Edit
  (`post-scope-audit.sh`) and Bash (`post-dep-audit.sh`).
- `settings.json` MUST register a Notification hook on `idle_prompt`
  running `notify.sh`.
- `settings.json` MUST register a SessionStart hook running
  `session-start-banner.sh`.

### Hooks

- `pre-security.sh` MUST scan the file_path argument (Read/Write/Edit)
  and the command string (Bash) against sensitive path patterns and
  sensitive directory references; MUST return a `permissionDecision` of
  `ask` for partial matches and `deny` for path traversal.
- `pre-commit-validate.sh` MUST mirror the global git `commit-msg` hook
  rules (conventional commits, no AI attribution, no emoji) but applied
  pre-commit so Claude Code never proposes a violating commit.
- `pre-code-no-emoji.sh` MUST detect Unicode emoji ranges in proposed
  Write/Edit content and block the operation.
- `notify.sh` MUST send a Pushover notification when Claude Code becomes
  idle for user input, if `PUSHOVER_TOKEN` and `PUSHOVER_USER` are set.
- `session-start-banner.sh` MUST emit a SessionStart hook output that
  reminds about no-emoji, conventional commits, and credential deny
  rules, plus preferred CLI tools.

### Agents

- The dotfiles MUST ship 5 sub-agents under `claude-code/agents/`:
  `pm-spec` (PM), `architect-review` (architect), `implementer-tester`
  (build + test), `qa-reviewer` (QA), and `code-reviewer` (general).
- Each agent MUST be a markdown file with frontmatter declaring its tool
  allowlist.

### Commands

- The dotfiles MUST ship at least 16 slash commands under
  `claude-code/commands/`: `commit`, `pr-create`, `review-pr`,
  `security-audit`, `pipeline`, `feature-spec`, `debug`, `test`,
  `optimize`, `dependencies`, `refactor`, `deploy-checklist`, `docs`,
  `changelog`, `fix-issue`, `context-prime`.
- The `pipeline` command MUST orchestrate the 4-stage flow
  (PM -> Architect -> Implementer -> QA) with a user checkpoint between
  each stage.

### Status line

- `statusLine` MUST run `~/.claude/statusline.sh` with `padding: 0`.
- `statusline.sh` MUST display the current git branch, working tree
  status indicator, context-usage bar, and active model name.

### CLAUDE.md

- `claude-code/CLAUDE.md` MUST contain guardrails matching the per-repo
  AGENTS.md (no emoji, conventional commits, credential deny lists),
  preferred CLI tools, MCP posture, and tool-use discipline (built-in
  Grep/Glob over Bash rg/grep).

## Scenarios

### Scenario: Deny list blocks .env read

GIVEN Claude Code is configured with the deployed `settings.json`
WHEN Claude attempts `Read(file_path: "/workspaces/foo/.env")`
THEN the `Read(**/.env)` deny rule matches
AND the framework rejects the call before `pre-security.sh` runs.

### Scenario: pre-security.sh asks on credential dir

GIVEN Claude Code attempts `Bash(command: "ls ~/.ssh/")`
WHEN `pre-security.sh` runs (via PreToolUse on Bash)
THEN the hook detects `.ssh/` in the command string
AND emits `{permissionDecision: "ask", permissionDecisionReason: "This command may access sensitive directory: .ssh"}`
AND the user gets a prompt before the command runs.

### Scenario: SessionStart banner reminds about guardrails

GIVEN a new Claude Code session starts in any repo
WHEN the SessionStart hook fires
THEN `session-start-banner.sh` emits a system reminder
mentioning no-emoji, conventional commits, no credential reads, and
preferred CLI tools (sg, difft, sd, scc, yq).

### Scenario: pipeline command runs PM -> Architect -> Build -> QA

GIVEN the user types `/pipeline add login feature`
WHEN the command runs
THEN Claude spawns the `pm-spec` agent (Read/Grep/Write tools only)
AND pauses for user review of the spec
AND continues with `architect-review` (Read/Grep/Glob)
AND pauses for user review of the ADR
AND continues with `implementer-tester` (Read/Write/Edit/Bash)
AND finishes with `qa-reviewer` (Read/Bash/Grep/Glob).

## Non-Behavior

- The Claude Code config does NOT install any MCP servers (MCP bypasses
  deny rules).
- The hooks do NOT log every tool call (privacy / token cost).
- The hooks do NOT send credentials anywhere; `notify.sh` requires
  user-set `PUSHOVER_TOKEN`/`PUSHOVER_USER` env vars.
- The pipeline command does NOT auto-merge or auto-push; only the
  Implementer agent has Write access and a user checkpoint precedes it.
- The deployed CLAUDE.md does NOT contain project-specific instructions
  (those live in per-repo `CLAUDE.md` and `AGENTS.md`).
