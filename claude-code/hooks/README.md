# Claude Code Hooks

Universal hook entrypoints for Claude Code that work across all projects.
The guardrail implementations are shared with Codex in `agent-hooks/` and
deployed to `~/.agent-hooks/`; `~/.claude/hooks/` contains Claude-specific
wrappers plus notification/session hooks.

## Included Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| pre-security.sh | Read/Write/Edit/Bash | Protects sensitive files (.env, credentials, keys) |
| pre-commit-validate.sh | Bash (git commit) | Validates conventional commits, blocks AI attribution |
| pre-code-no-emoji.sh | Write/Edit | Blocks emoji characters in code files |
| notify.sh | Notification | Cross-platform desktop alert when Claude needs attention |
| *(inline)* | SessionStart (compact) | Re-injects key rules after context compaction |

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
