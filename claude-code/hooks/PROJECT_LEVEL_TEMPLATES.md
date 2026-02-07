# Project-Level Hook Templates

## When to Use Each Hook Type

| Hook Location | Use When | Examples |
|---------------|----------|----------|
| Dotfiles (universal) | Works identically across ALL projects, no project config needed | Security checks, dangerous command blocking, context monitoring |
| Project `.claude/hooks/` | Depends on project tooling, frameworks, or conventions | Formatters, linters, test runners, build validation |

## Setup

1. Create `.claude/hooks/` in project root
2. Add hook scripts (see templates below)
3. Make executable: `chmod +x .claude/hooks/*.sh`
4. Configure in `.claude/settings.json`

## Template: Auto-Formatting (PostToolUse)

```bash
#!/usr/bin/env bash
# Post-tool formatting hook
command -v jq &>/dev/null || { echo "Error: jq required" >&2; exit 1; }
read -r input
FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

case "${FILE_PATH##*.}" in
    js|jsx|ts|tsx) command -v prettier &>/dev/null && prettier --write "$FILE_PATH" ;;
    py) command -v black &>/dev/null && black -q "$FILE_PATH" ;;
    go) command -v gofmt &>/dev/null && gofmt -w "$FILE_PATH" ;;
    rs) command -v rustfmt &>/dev/null && rustfmt "$FILE_PATH" ;;
esac
exit 0
```

## Template: Test Runner (PostToolUse)

```bash
#!/usr/bin/env bash
# Post-tool test runner
command -v jq &>/dev/null || { echo "Error: jq required" >&2; exit 1; }
read -r input
FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" || "$FILE_PATH" == *"test"* || "$FILE_PATH" == *"spec"* ]] && exit 0

case "${FILE_PATH##*.}" in
    js|jsx|ts|tsx) npm test -- --findRelatedTests "$FILE_PATH" --passWithNoTests 2>&1 | head -20 ;;
    py) pytest -v 2>&1 | head -20 ;;
    go) go test "$(dirname "$FILE_PATH")" -v 2>&1 | head -20 ;;
esac
exit 0
```

## Configuration Example

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "command": ".claude/hooks/post-format.sh",
        "tools": ["Write", "Edit"],
        "timeout": 10
      }
    ]
  }
}
```
