# Claude Code Hooks

Universal hooks for Claude Code that work across all projects.

## Included Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| pre-security.sh | Read/Write/Edit | Protects sensitive files (.env, credentials, keys) |
| pre-auto-approve-docs.sh | Read | Auto-approves safe documentation files |
| pre-bash-validate.sh | Bash | Suggests better commands, blocks dangerous operations |
| pre-commit-validate.sh | Bash (git commit) | Validates conventional commits, blocks AI attribution |
| session-git-context.sh | SessionStart | Injects git context at session start |

## Configuration

Hooks are configured in `~/.claude/settings.json`. To disable a hook, remove its entry from settings.

Scripts are in `~/.claude/hooks/` and can be edited directly - changes take effect immediately.

## Troubleshooting

### Hook Not Running
1. Check executable: `ls -la ~/.claude/hooks/`
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
