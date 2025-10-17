# Project-Level Hook Templates

This document provides templates and guidance for creating project-specific Claude Code hooks. These hooks should live in your project's `.claude/hooks/` directory, not in your dotfiles.

## When to Use Project-Level vs. Dotfiles Hooks

### Use Dotfiles Hooks (Universal) When:
- The hook works identically across ALL projects
- No project-specific configuration is needed
- It provides universal safety, security, or quality checks
- Examples: security checks, dangerous command blocking, context monitoring

### Use Project-Level Hooks When:
- The hook depends on project-specific tooling or configuration
- It requires specific frameworks, dependencies, or project structure
- It enforces project-specific conventions or standards
- Different projects would need different implementations
- Examples: formatters, linters, test runners, deployment checks

## Setting Up Project-Level Hooks

1. Create `.claude/hooks/` directory in your project root
2. Copy templates from this document and customize them
3. Make hooks executable: `chmod +x .claude/hooks/*.sh`
4. Configure in `.claude/settings.json` (see examples below)

## Template: Auto-Formatting Hook

**Use Case:** Automatically format code after Write/Edit operations

**Customize:** Update formatter commands and file extensions for your project

```bash
#!/usr/bin/env bash
# Post-tool formatting hook - Auto-format code after writes
# Project-specific configuration

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only format after Write or Edit operations
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
    exit 0
fi

if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
    exit 0
fi

FILE_EXT="${FILE_PATH##*.}"
FORMATTED=false

# ============================================================================
# CUSTOMIZE THIS SECTION FOR YOUR PROJECT
# ============================================================================

case "$FILE_EXT" in
    # JavaScript/TypeScript - Prettier
    js|jsx|ts|tsx)
        if command -v prettier &> /dev/null; then
            # Use your project's prettier config
            if prettier --write "$FILE_PATH" 2>&1; then
                FORMATTED=true
            fi
        fi
        ;;

    # Python - Black (or ruff, yapf, autopep8)
    py)
        if command -v black &> /dev/null; then
            # Use your project's black config (pyproject.toml)
            if black -q "$FILE_PATH" 2>&1; then
                FORMATTED=true
            fi
        fi
        ;;

    # Go - gofmt or goimports
    go)
        if command -v goimports &> /dev/null; then
            if goimports -w "$FILE_PATH" 2>&1; then
                FORMATTED=true
            fi
        elif command -v gofmt &> /dev/null; then
            if gofmt -w "$FILE_PATH" 2>&1; then
                FORMATTED=true
            fi
        fi
        ;;

    # Rust - rustfmt
    rs)
        if command -v rustfmt &> /dev/null; then
            # Uses rustfmt.toml in project root
            if rustfmt "$FILE_PATH" 2>&1; then
                FORMATTED=true
            fi
        fi
        ;;

    # Add more formatters as needed for your project
    # ruby)
    #     if command -v rubocop &> /dev/null; then
    #         if rubocop -a "$FILE_PATH" 2>&1; then
    #             FORMATTED=true
    #         fi
    #     fi
    #     ;;
esac

# ============================================================================

if [[ "$FORMATTED" == "true" ]]; then
    echo "Formatted: $(basename "$FILE_PATH")" >&2
fi

exit 0
```

**Configuration in `.claude/settings.json`:**
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

## Template: Test Runner Hook

**Use Case:** Run relevant tests after code changes

**Customize:** Update test commands and patterns for your test framework

```bash
#!/usr/bin/env bash
# Post-tool test runner hook - Run tests after code changes
# Project-specific configuration

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')
CWD=$(echo "$input" | jq -r '.cwd // empty')

# Only run tests after Write or Edit operations
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
    exit 0
fi

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Skip if this is already a test file (avoid recursion)
FILE_NAME=$(basename "$FILE_PATH")
if [[ "$FILE_NAME" == *"test"* ]] || [[ "$FILE_NAME" == *"spec"* ]]; then
    exit 0
fi

cd "$CWD" || exit 0

FILE_EXT="${FILE_PATH##*.}"

# ============================================================================
# CUSTOMIZE THIS SECTION FOR YOUR PROJECT
# ============================================================================

case "$FILE_EXT" in
    # JavaScript/TypeScript - Jest
    js|jsx|ts|tsx)
        if [[ -f "package.json" ]] && command -v npm &> /dev/null; then
            echo "Running tests for $(basename "$FILE_PATH")..." >&2
            # Run tests related to the changed file
            npm test -- --findRelatedTests "$FILE_PATH" --passWithNoTests 2>&1 | head -20
        fi
        ;;

    # Python - pytest
    py)
        if command -v pytest &> /dev/null; then
            echo "Running tests for $(basename "$FILE_PATH")..." >&2
            # Try to find and run related test file
            # Adjust these patterns to match your project structure
            TEST_FILE="${FILE_PATH/%.py/_test.py}"
            TEST_FILE="${TEST_FILE//\/src\//\/tests\/}"
            if [[ -f "$TEST_FILE" ]]; then
                pytest "$TEST_FILE" -v 2>&1 | head -20
            fi
        fi
        ;;

    # Go - go test
    go)
        if command -v go &> /dev/null; then
            echo "Running tests for $(basename "$FILE_PATH")..." >&2
            PKG_DIR=$(dirname "$FILE_PATH")
            go test "$PKG_DIR" -v 2>&1 | head -20
        fi
        ;;

    # Rust - cargo test
    rs)
        if [[ -f "Cargo.toml" ]] && command -v cargo &> /dev/null; then
            echo "Running tests for $(basename "$FILE_PATH")..." >&2
            cargo test --quiet 2>&1 | head -20
        fi
        ;;

    # Add more test runners as needed for your project
    # ruby)
    #     if command -v rspec &> /dev/null; then
    #         echo "Running tests for $(basename "$FILE_PATH")..." >&2
    #         rspec "$FILE_PATH" 2>&1 | head -20
    #     fi
    #     ;;
esac

# ============================================================================

exit 0
```

**Configuration in `.claude/settings.json`:**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "command": ".claude/hooks/post-test-runner.sh",
        "tools": ["Write", "Edit"],
        "timeout": 30
      }
    ]
  }
}
```

## Template: Linting Hook

**Use Case:** Run linters before committing code

```bash
#!/usr/bin/env bash
# Pre-tool linting hook - Check code quality before operations

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only check before Write or Edit
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
    exit 0
fi

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

FILE_EXT="${FILE_PATH##*.}"

# Run appropriate linter
case "$FILE_EXT" in
    js|jsx|ts|tsx)
        if command -v eslint &> /dev/null; then
            if ! eslint "$FILE_PATH" 2>&1; then
                echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"ask\",
    \"permissionDecisionReason\": \"ESLint found issues. Proceed anyway?\"
  }
}" | jq -c
                exit 0
            fi
        fi
        ;;

    py)
        if command -v ruff &> /dev/null; then
            if ! ruff check "$FILE_PATH" 2>&1; then
                echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"ask\",
    \"permissionDecisionReason\": \"Ruff found issues. Proceed anyway?\"
  }
}" | jq -c
                exit 0
            fi
        fi
        ;;
esac

exit 0
```

**Configuration in `.claude/settings.json`:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "command": ".claude/hooks/pre-lint.sh",
        "tools": ["Write", "Edit"],
        "timeout": 10
      }
    ]
  }
}
```

## Template: Project-Specific Git Commit Validation

**Use Case:** Enforce project-specific commit conventions (ticket numbers, team standards)

```bash
#!/usr/bin/env bash
# Pre-tool commit validation hook - Project-specific commit rules

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
COMMAND=$(echo "$input" | jq -r '.tool_input.command // empty')

if [[ "$TOOL_NAME" != "Bash" ]] || [[ ! "$COMMAND" =~ git[[:space:]]+commit ]]; then
    exit 0
fi

# Extract commit message
COMMIT_MSG=""
if [[ "$COMMAND" =~ -m[[:space:]]+\"([^\"]*)\" ]]; then
    COMMIT_MSG="${BASH_REMATCH[1]}"
elif [[ "$COMMAND" =~ \$\(cat[[:space:]]+\<\<.*EOF ]]; then
    COMMIT_MSG=$(echo "$COMMAND" | sed -n '/cat.*<<.*EOF/,/EOF/p' | sed '1d;$d' | head -1)
fi

if [[ -z "$COMMIT_MSG" ]]; then
    exit 0
fi

# ============================================================================
# CUSTOMIZE THESE RULES FOR YOUR PROJECT
# ============================================================================

# Example: Require Jira ticket numbers
if [[ ! "$COMMIT_MSG" =~ JIRA-[0-9]+ ]]; then
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"ask\",
    \"permissionDecisionReason\": \"Commit message should include a Jira ticket (e.g., JIRA-123). Proceed anyway?\"
  }
}" | jq -c
    exit 0
fi

# Example: Block WIP commits on main branch
BRANCH=$(git branch --show-current 2>/dev/null)
if [[ "$BRANCH" == "main" ]] && [[ "$COMMIT_MSG" =~ [Ww][Ii][Pp] ]]; then
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"WIP commits are not allowed on main branch\"
  }
}" | jq -c
    exit 0
fi

# ============================================================================

exit 0
```

**Configuration in `.claude/settings.json`:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "command": ".claude/hooks/pre-commit-project.sh",
        "tools": ["Bash"],
        "timeout": 5
      }
    ]
  }
}
```

## Template: Build Validation Hook

**Use Case:** Run build before allowing commits or deployments

```bash
#!/usr/bin/env bash
# Pre-tool build validation hook

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this hook" >&2
    exit 1
fi

read -r input

TOOL_NAME=$(echo "$input" | jq -r '.tool_name // empty')
COMMAND=$(echo "$input" | jq -r '.tool_input.command // empty')
CWD=$(echo "$input" | jq -r '.cwd // empty')

# Only check before git commits
if [[ "$TOOL_NAME" != "Bash" ]] || [[ ! "$COMMAND" =~ git[[:space:]]+commit ]]; then
    exit 0
fi

cd "$CWD" || exit 0

# Run build command (customize for your project)
if [[ -f "package.json" ]]; then
    if ! npm run build 2>&1; then
        echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"Build failed. Fix build errors before committing.\"
  }
}" | jq -c
        exit 0
    fi
fi

exit 0
```

## Additional Project-Specific Hook Ideas

### Development Workflow
- **Pre-push hook**: Run full test suite before pushing
- **Post-merge hook**: Install dependencies after git merge
- **Branch protection**: Prevent commits to protected branches
- **Dependency check**: Verify package.json/requirements.txt changes are valid

### Code Quality
- **Type checking**: Run TypeScript, mypy, or other type checkers
- **Coverage check**: Ensure test coverage meets threshold
- **Documentation check**: Verify JSDoc, docstrings, or API docs are updated
- **Import validation**: Check for circular dependencies or banned imports

### Security & Compliance
- **Secrets scanning**: Check for accidentally committed API keys (project-specific patterns)
- **License compliance**: Verify new dependencies have acceptable licenses
- **Code ownership**: Verify changes to critical files have proper review
- **Audit logging**: Log specific operations for compliance

### Deployment & Release
- **Version bump check**: Verify version numbers are updated for releases
- **Changelog validation**: Ensure CHANGELOG.md is updated
- **Migration check**: Verify database migrations are created for schema changes
- **Environment validation**: Check environment-specific configs are updated

## Best Practices

1. **Keep hooks fast**: Slow hooks disrupt workflow (aim for <5 seconds)
2. **Make them optional**: Allow developers to bypass in emergencies
3. **Provide clear feedback**: Explain why a hook blocked an action
4. **Document your hooks**: Add comments and maintain project documentation
5. **Version control**: Commit hooks to project repo, not dotfiles
6. **Test thoroughly**: Broken hooks can block all development
7. **Use appropriate timeouts**: Set realistic timeout values in settings.json

## Combining Dotfiles and Project-Level Hooks

Your dotfiles provide universal safety and quality checks. Project-level hooks add project-specific validations. Together they create a comprehensive development safety net:

```
Universal (Dotfiles)          Project-Specific (.claude/hooks/)
├── Security checks           ├── Formatters (Prettier, Black)
├── Dangerous commands        ├── Test runners (Jest, pytest)
├── Context monitoring        ├── Linters (ESLint, Ruff)
├── Git context               ├── Build validation
└── Basic commit hygiene      └── Project conventions
```

Both sets of hooks work together seamlessly!

## Resources

- [Claude Code Hooks Documentation](https://docs.claude.com/en/docs/claude-code/hooks)
- [Hook Event Reference](https://docs.claude.com/en/docs/claude-code/hooks#hook-events)
- [Example Hooks Repository](https://github.com/anthropics/claude-code-examples/tree/main/hooks)
