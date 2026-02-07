# Claude Code Tool Logging

Logs all Claude Code tool usage to JSONL format in `~/.claude/logs/`.

## Configuration

Set log level in shell profile:

```bash
export CLAUDE_LOG_LEVEL="bash_only"        # Minimal: Bash commands only
export CLAUDE_LOG_LEVEL="state_modifying"  # Default: Bash, Write, Edit, NotebookEdit
export CLAUDE_LOG_LEVEL="all"              # Verbose: All tools
```

## Query Helper

```bash
alias cclog='~/.dotfiles/claude-code/hooks/query-tool-logs.sh'

cclog last              # View most recent session
cclog sessions          # List all sessions
cclog bash              # Show Bash commands
cclog tool Write        # Show Write operations
cclog search "pattern"  # Search logs
cclog stats             # Show statistics
cclog watch             # Watch current session
```

## Direct Queries

```bash
# Failed commands
jq -r 'select(.tool_name == "Bash" and .tool_response.exitCode != 0)' ~/.claude/logs/session-*.jsonl

# Files written
jq -r 'select(.tool_name == "Write") | .tool_input.file_path' ~/.claude/logs/session-*.jsonl

# Tool usage count
jq -r '.tool_name' ~/.claude/logs/session-*.jsonl | sort | uniq -c | sort -rn
```

## Log Management

```bash
# Delete logs older than 30 days
find ~/.claude/logs -name "session-*.jsonl" -mtime +30 -delete

# Check log size
du -sh ~/.claude/logs
```

## Troubleshooting

**No logs**: Check hook is executable (`ls -l ~/.dotfiles/claude-code/hooks/post-tool-logger.sh`)

**Logs too large**: Change to `bash_only` level or run cleanup
