# Claude Code Tool Usage Logging

A comprehensive logging system for tracking all Claude Code tool usage. Logs are stored in easily searchable JSONL format with intelligent truncation to keep file sizes manageable while preserving essential information.

## Overview

This system uses a PostToolUse hook to capture every tool execution by Claude Code, including:
- **Bash commands** with full command text, exit codes, and stdout/stderr
- **File operations** (Write, Edit, NotebookEdit) with file paths and content metadata
- **All other tools** with input/output tracking

Logs are stored per-session in `~/.claude/logs/session-{session_id}.jsonl` for easy organization and searchability.

## Features

- ✅ **Intelligent truncation**: Keeps log files manageable while preserving critical information
- ✅ **Per-session logs**: Automatic log rotation by session
- ✅ **JSONL format**: Easily searchable with `jq`, `grep`, or any JSON tool
- ✅ **Configurable log levels**: Choose what to track (bash only, state-modifying, or all tools)
- ✅ **Rich metadata**: Includes timestamps, git branch, working directory, and more
- ✅ **Helper scripts**: Query logs with simple commands
- ✅ **Zero overhead**: Non-blocking, fast execution

## Configuration

### Log Levels

Control what gets logged by setting the `CLAUDE_LOG_LEVEL` environment variable:

```bash
# In your shell profile (~/.bashrc, ~/.zshrc, etc.)

# Option 1: Log only Bash commands (minimal)
export CLAUDE_LOG_LEVEL="bash_only"

# Option 2: Log state-modifying tools (recommended - default)
export CLAUDE_LOG_LEVEL="state_modifying"  # Bash, Write, Edit, NotebookEdit

# Option 3: Log all tools (verbose)
export CLAUDE_LOG_LEVEL="all"
```

If not set, defaults to `state_modifying`.

### Hook Configuration

The PostToolUse hook is configured in `~/.dotfiles/claude-code/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/post-tool-logger.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

## Usage

### Query Helper Script

Use the `query-tool-logs.sh` helper script for easy log access:

```bash
# Add to your PATH or create an alias
alias cclog='~/.dotfiles/claude-code/hooks/query-tool-logs.sh'

# View most recent session
cclog last

# List all sessions
cclog sessions

# View specific session
cclog session <session-id>

# Show all Bash commands
cclog bash

# Show all Write operations
cclog tool Write

# Search for specific pattern
cclog search "git commit"

# Show statistics
cclog stats

# Watch current session in real-time
cclog watch

# Verbose output with full tool inputs/outputs
cclog last --verbose
```

### Direct JSONL Queries

Use `jq` for powerful queries:

```bash
# Get all bash commands from last session
jq -r 'select(.tool_name == "Bash") | .tool_input.command' \
  ~/.claude/logs/session-*.jsonl | tail -20

# Find failed commands
jq -r 'select(.tool_name == "Bash" and .tool_response.exitCode != 0) |
  "\(.timestamp): \(.tool_input.command) (exit: \(.tool_response.exitCode))"' \
  ~/.claude/logs/session-*.jsonl

# Get all files written in a session
jq -r 'select(.tool_name == "Write") | .tool_input.file_path' \
  ~/.claude/logs/session-abc123.jsonl

# Count tool usage
jq -r '.tool_name' ~/.claude/logs/session-*.jsonl | sort | uniq -c | sort -rn

# Get commands run in specific directory
jq -r 'select(.cwd == "/path/to/project") | .tool_input.command' \
  ~/.claude/logs/session-*.jsonl
```

## Log Format

Each log entry is a JSON object with the following structure:

```json
{
  "timestamp": "2025-10-17T12:34:56.789Z",
  "session_id": "abc123...",
  "tool_name": "Bash",
  "tool_input": {
    "command": "git status",
    "description": "Check git status"
  },
  "tool_response": {
    "stdout": "On branch main...",
    "stderr": "",
    "exitCode": 0,
    "metadata": {
      "stdout_lines": 10,
      "stderr_lines": 0
    }
  },
  "cwd": "/home/user/project",
  "git_branch": "main"
}
```

### Tool-Specific Formats

#### Bash
```json
{
  "tool_input": {
    "command": "npm install",
    "description": "Install dependencies"
  },
  "tool_response": {
    "stdout": "...(truncated if > 500 lines)...",
    "stderr": "...",
    "exitCode": 0,
    "metadata": {
      "stdout_lines": 1234,
      "stderr_lines": 0
    }
  }
}
```

#### Write
```json
{
  "tool_input": {
    "file_path": "/path/to/file.js",
    "content": "...(truncated if > 500 chars)...",
    "metadata": {
      "content_length": 5678,
      "content_lines": 150
    }
  }
}
```

#### Edit
```json
{
  "tool_input": {
    "file_path": "/path/to/file.js",
    "old_string": "...(truncated if > 500 chars)...",
    "new_string": "...(truncated if > 500 chars)...",
    "replace_all": false,
    "metadata": {
      "old_string_length": 234,
      "new_string_length": 345
    }
  }
}
```

## Truncation Strategy

The logging system uses intelligent truncation to balance detail with file size:

### Bash Output
- **Full output** if ≤ 500 lines
- **Truncated output** if > 500 lines: keeps first 200 + last 100 lines
- Stores original line count in metadata

### Write/Edit Content
- **Full content** if ≤ 500 characters
- **Truncated** if > 500 chars: keeps first 250 + last 250 characters
- Stores original length in metadata

### Tool Response
- Generally limited to 1000 characters
- Success/failure status always preserved
- Error messages never truncated

## Log Management

### Storage Location
```
~/.claude/logs/
├── session-abc123.jsonl      # Session logs
├── session-def456.jsonl
└── session-ghi789.jsonl
```

### Log Rotation
- **Automatic**: New file created per session
- **Manual cleanup**: Remove old session logs as needed

```bash
# Delete logs older than 30 days
find ~/.claude/logs -name "session-*.jsonl" -mtime +30 -delete

# Compress logs older than 7 days
find ~/.claude/logs -name "session-*.jsonl" -mtime +7 -exec gzip {} \;

# Archive by month
mkdir -p ~/.claude/logs/archive/$(date +%Y-%m)
mv ~/.claude/logs/session-*.jsonl ~/.claude/logs/archive/$(date +%Y-%m)/
```

### Log Size Management

Typical log sizes:
- **bash_only**: ~10-50 KB per session
- **state_modifying**: ~50-200 KB per session
- **all**: ~500 KB - 2 MB per session

## Advanced Usage

### Create Custom Queries

```bash
# Most used commands
jq -r 'select(.tool_name == "Bash") | .tool_input.command' \
  ~/.claude/logs/session-*.jsonl | \
  awk '{print $1}' | sort | uniq -c | sort -rn | head -20

# Commands that failed
jq -r 'select(.tool_name == "Bash" and .tool_response.exitCode != 0) |
  [.timestamp, .tool_input.command, .tool_response.exitCode] | @csv' \
  ~/.claude/logs/session-*.jsonl

# Activity timeline
jq -r '[.timestamp, .tool_name, .cwd] | @tsv' \
  ~/.claude/logs/session-*.jsonl | \
  column -t -s $'\t'

# Files modified
jq -r 'select(.tool_name == "Write" or .tool_name == "Edit") |
  .tool_input.file_path' \
  ~/.claude/logs/session-*.jsonl | sort -u
```

### Integration with Other Tools

```bash
# Export to CSV for spreadsheet analysis
jq -r 'select(.tool_name == "Bash") |
  [.timestamp, .tool_input.command, .tool_response.exitCode, .cwd] | @csv' \
  ~/.claude/logs/session-*.jsonl > commands.csv

# Generate activity report
cclog stats > activity-report.txt

# Feed into data analysis tools
jq -c '.' ~/.claude/logs/session-*.jsonl | \
  python analyze_claude_usage.py
```

## Best Practices

1. **Set appropriate log level**: Start with `state_modifying`, upgrade to `all` only when debugging
2. **Regular cleanup**: Set up a cron job to archive/delete old logs
3. **Use helper script**: `cclog` is faster than manual `jq` queries for common tasks
4. **Session tracking**: Note session IDs for important work sessions
5. **Compress archives**: Use `gzip` for long-term log storage
6. **Monitor disk usage**: Check log directory size periodically

```bash
# Check log directory size
du -sh ~/.claude/logs

# Count sessions
ls ~/.claude/logs/session-*.jsonl | wc -l
```

## Troubleshooting

### No logs appearing
1. Check hook is installed: `cat ~/.claude/settings.json | jq '.hooks.PostToolUse'`
2. Verify script is executable: `ls -l ~/.dotfiles/claude-code/hooks/post-tool-logger.sh`
3. Check for errors: Look for hook error messages in Claude Code output
4. Test manually: `echo '{"session_id":"test","tool_name":"Bash",...}' | ~/.dotfiles/claude-code/hooks/post-tool-logger.sh`

### Logs are too large
1. Change log level to `bash_only` or `state_modifying`
2. Implement regular cleanup (see Log Management above)
3. Adjust truncation limits in `post-tool-logger.sh`

### Missing jq dependency
```bash
# Install jq
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# Arch
sudo pacman -S jq
```

## Environment Variables

- `CLAUDE_LOG_LEVEL`: Controls what tools to log (bash_only, state_modifying, all)
- `CLAUDECODE`: Automatically set by Claude Code (used to detect Claude environment)

## Files

- `~/.dotfiles/claude-code/hooks/post-tool-logger.sh` - Main logging hook
- `~/.dotfiles/claude-code/hooks/query-tool-logs.sh` - Query helper script
- `~/.dotfiles/claude-code/settings.json` - Hook configuration
- `~/.claude/logs/` - Log storage directory

## Examples

### Daily Development Review

```bash
# What did Claude do today?
cclog last | grep -A 5 "Bash"

# What files were modified?
cclog tool Write | grep "File:"
cclog tool Edit | grep "File:"

# Any failed commands?
jq -r 'select(.tool_name == "Bash" and .tool_response.exitCode != 0)' \
  $(cclog sessions | grep "$(date +%Y-%m-%d)" | awk '{print $2}' | head -1)
```

### Audit Trail for Commits

```bash
# What commands led to the last commit?
cclog bash | grep -B 5 "git commit"

# What files were changed?
cclog tool Write
cclog tool Edit
```

### Performance Analysis

```bash
# Which tools does Claude use most?
cclog stats | grep "Tool usage"

# How many bash commands per session?
for log in ~/.claude/logs/session-*.jsonl; do
  count=$(jq -r 'select(.tool_name == "Bash")' "$log" | wc -l)
  echo "$(basename "$log"): $count bash commands"
done
```

## See Also

- [Claude Code Hooks Documentation](https://docs.claude.com/en/docs/claude-code/hooks)
- [jq Manual](https://jqlang.github.io/jq/manual/)
- `man jq` - jq command-line JSON processor
