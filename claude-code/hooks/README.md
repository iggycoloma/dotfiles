# Claude Code Hooks

Universal hook entrypoints for Claude Code that work across all projects.
The guardrail implementations are shared with Codex in `agent-hooks/` and
deployed to `~/.agent-hooks/`; `~/.claude/hooks/` contains Claude-specific
wrappers plus notification/session hooks.

## Included Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| pre-security.sh | PreToolUse: Read/Write/Edit | Protects sensitive files (.env, credentials, keys). Bash is not scanned -- `sandbox.credentials` covers it; see docs/sandbox.md "Why there is no Bash scan" |
| pre-code-no-emoji.sh | PreToolUse: Write/Edit | Blocks emoji characters in code files |
| pre-hookspath-guard.sh | PreToolUse: Bash (`if: git *`) | Denies `git config` writes to `core.hooksPath`, which would silently disable the global gitleaks and commit-msg hooks. Reads and unsets pass |
| post-scope-audit.sh | PostToolUse: Write/Edit | Logs writes that escape the project scope to `~/.local/state/ralph/scope-audit.log` (audit-only, never blocks) |
| post-dep-audit.sh | PostToolUse: Bash | Runs the matching vulnerability audit (npm audit, pip-audit, cargo audit, govulncheck) after install commands; logs to `~/.local/state/ralph/audit.log`. `RALPH_AUDIT_BLOCKING=1` feeds failures back to the agent via exit 2 |
| post-bash-failure.sh | PostToolUseFailure: Bash | Logs failed Bash commands to `~/.local/state/claude-code/bash-failures.log` (complements post-dep-audit, which only sees successes) |
| config-change-guard.sh | ConfigChange | Blocks mid-session settings/skills reloads; edits stay on disk and apply next session. `DOTFILES_ALLOW_CONFIG_RELOAD=1` for sanctioned changes |
| notify.sh | Notification: idle_prompt, permission_prompt, agent_needs_input | Pushover alert when Claude needs attention |
| session-start-banner.sh | SessionStart | Re-injects key rules at session start and after compaction; stricter banner under `CLAUDE_UNATTENDED=1` |
| session-end-ledger.sh | SessionEnd | Appends per-session token/cost/duration totals (from the transcript) to `~/.local/state/claude-code/session-ledger.csv` |
| subagent-audit.sh | SubagentStart/SubagentStop | One JSONL line per subagent event, with duration at stop, in `~/.local/state/claude-code/agent-audit.jsonl` |
| worktree-create.sh / worktree-remove.sh | WorktreeCreate/WorktreeRemove | Routes Claude Code worktree lifecycle through `wt` (provisioning, ports, containers), with plain-git fallback |

Commit message validation (conventional-commit format, no AI attribution, no
emoji) is handled by git's `commit-msg` hook at `git/hooks/commit-msg`, wired
globally via `core.hooksPath`. It runs against the resolved message file after
git has handled every input form (`-m`, `-F`, `--file=`, `-t`, heredoc,
editor), so coverage is uniform. There is no PreToolUse equivalent here.

## Configuration

Hooks are configured in `~/.claude/settings.json`. To disable a hook, remove its entry from settings.

The guardrail wrapper scripts are in `~/.claude/hooks/`. Edit shared guardrail
logic in `agent-hooks/` so Claude and Codex stay aligned.

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
