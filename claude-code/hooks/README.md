# Claude Code Hooks

Universal hook entrypoints for Claude Code that work across all projects.
Cross-harness policies and metadata-only telemetry live in `agent-hooks/` and
are deployed to `~/.agent-hooks/`. `~/.claude/hooks/` contains only adapters
for Claude-specific events, notifications, transcript parsing, and worktrees.

## Included Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| pre-security.sh | PreToolUse: Read/Write/Edit | Protects sensitive files (.env, credentials, keys). Bash is not scanned -- `sandbox.credentials` covers it; see docs/sandbox.md "Why there is no Bash scan" |
| pre-code-no-emoji.sh | PreToolUse: Write/Edit | Blocks emoji characters in code files |
| `~/.agent-hooks/pre-hookspath-guard.sh` | PreToolUse: Bash (`if: git *`) | Denies `git config` writes to `core.hooksPath`; reads and unsets pass |
| `~/.agent-hooks/pre-leading-token-guard.sh` | PreToolUse: Bash | Denies commands that bury a sandbox-excluded tool (`glab`, `gh`, `wt`, `docker`, `devcontainer`) behind another leading token, where it would run sandboxed and die on its denied config dir |
| `~/.agent-hooks/post-scope-audit.sh` | PostToolUse: Write/Edit | Logs out-of-scope writes as structured events (audit-only) |
| `~/.agent-hooks/post-dep-audit.sh` | PostToolUse: Bash | Audits dependency graphs after install commands; `AGENT_DEP_AUDIT_FEEDBACK=1` feeds failures back via exit 2 |
| `~/.agent-hooks/tool-telemetry.sh` | PostToolUse + PostToolUseFailure: Bash | Logs executable class, outcome, exit code, interruption, and duration; never command arguments or output |
| config-change-guard.sh | ConfigChange | Silently blocks settings/skills reloads in the live session; edits remain on disk for review and the next session |
| notify.sh | Notification: idle_prompt, permission_prompt, agent_needs_input | Pushover alert when Claude needs attention |
| session-start-banner.sh | SessionStart | Prints the unattended-mode rules under `CLAUDE_UNATTENDED=1`; silent otherwise, since attended sessions already load the same rules from CLAUDE.md |
| model-context.sh | SessionStart | Prints the `~/.claude/model-adjustments/` fragment matching the session's model id (e.g. Opus 5 verbosity corrections); silent when the optional `model` field is absent or no fragment matches |
| session-end-ledger.sh | SessionEnd | Appends Claude transcript-derived usage totals to `~/.local/state/agent-hooks/session-ledger.csv`; this parser is intentionally harness-specific |
| `~/.agent-hooks/session-audit.sh` | SessionStart/SessionEnd | Records metadata-only lifecycle events shared with Codex |
| `~/.agent-hooks/subagent-audit.sh` | SubagentStart/SubagentStop | Records metadata-only subagent lifecycle and duration shared with Codex |
| `~/.agent-hooks/hook-health.sh` | SessionStart | Surfaces missing prerequisites and shared hook deployments |
| worktree-create.sh / worktree-remove.sh | WorktreeCreate/WorktreeRemove | Routes Claude Code worktree lifecycle through `wt` (provisioning, ports, containers), with plain-git fallback |

Fail-open vs fail-closed: `pre-security.sh` and `pre-code-no-emoji.sh` go
through `~/.claude/hooks/` wrappers that emit a deny when the shared
implementation is missing, because silently losing credential blocking is not
acceptable. `pre-hookspath-guard.sh` is wired directly to `~/.agent-hooks/`
and fails open by design: it is a tripwire on the honest path, not a security
boundary, and `hook-health.sh` surfaces a missing deployment at session start.

Commit message validation (conventional-commit format, no AI attribution, no
emoji) is handled by git's `commit-msg` hook at `git/hooks/commit-msg`, wired
globally via `core.hooksPath`. It runs against the resolved message file after
git has handled every input form (`-m`, `-F`, `--file=`, `-t`, heredoc,
editor), so coverage is uniform. There is no PreToolUse equivalent here.

## Configuration

Hooks are configured in `~/.claude/settings.json`. To disable a hook, remove its entry from settings.

Edit cross-harness behavior in `agent-hooks/`; keep Claude-only payload parsing
and lifecycle behavior in `claude-code/hooks/`.

## Troubleshooting

### Hook Not Running
1. Check executable: `ls -la ~/.claude/hooks/ ~/.agent-hooks/`
2. Test manually: `echo '{}' | ~/.claude/hooks/hook-name.sh`
3. Check logs: `~/.claude/debug/`

### Hook Timing Out
Increase timeout in settings.json:
```json
{ "timeout": 30 }
```

### Hook Errors
Hooks that exit with non-zero codes (except 2 for deny) are logged but don't block operations.

## Exit Codes

- `0` - Success, continue
- `2` - Block operation, show stderr as denial reason

## Project-Specific Hooks

For project-specific hooks (formatters, test runners, linters), use `.claude/hooks/` in your project directory. See [PROJECT_LEVEL_TEMPLATES.md](PROJECT_LEVEL_TEMPLATES.md) for templates.
