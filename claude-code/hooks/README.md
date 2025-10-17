# Claude Code Hooks

This directory contains universal, production-ready hooks for Claude Code that work across all projects. These hooks enhance developer productivity, enforce best practices, and maintain code quality without requiring project-specific configuration.

## Universal Hooks (6 Total)

### Pre-Tool Hooks (Run Before Tool Execution)

#### 1. **pre-security.sh** (Read|Write|Edit)
Protects sensitive files from accidental exposure.

**Features:**
- Asks for confirmation before accessing `.env`, credentials, private keys
- Blocks path traversal attempts (`..` in paths)
- Prevents accidental exposure of secrets

**Triggers:** Before Read, Write, or Edit operations

---

#### 2. **pre-auto-approve-docs.sh** (Read)
Automatically approves safe documentation file reads to speed up workflow.

**Features:**
- Auto-approves: `.md`, `.txt`, `.json`, `.yaml`, `README`, `LICENSE`, etc.
- Reduces permission prompts for documentation work
- Suppresses approval messages to reduce noise

**Triggers:** Before Read operations

---

#### 3. **pre-bash-validate.sh** (Bash)
Suggests better command alternatives and prevents dangerous operations.

**Features:**
- Suggests `rg` (ripgrep) instead of `grep`
- Suggests `fd` instead of `find`
- Blocks extremely dangerous commands (e.g., `rm -rf /`)
- Asks confirmation for risky operations (e.g., `chmod 777`)

**Triggers:** Before Bash commands

---

#### 4. **pre-commit-validate.sh** (Bash)
Universal commit message validation ensuring professional, clean commit messages.

**Features:**
- Blocks AI tool attribution (Claude, Claude Code, GPT, Copilot, etc.)
- Blocks co-authoring tags (`Co-Authored-By:`, `Co-authored-by:`)
- Blocks emoji characters in commit messages
- Validates conventional commits format
- Checks minimum message length (10+ chars)
- Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
- Example: `feat(auth): add user login functionality`

**Scope:** Universal, cross-project commit message hygiene only

**Triggers:** Before git commit commands

---


### Session Hooks

#### 5. **session-git-context.sh** (SessionStart)
Injects git context automatically at the start of each session.

**Features:**
- Shows current branch and remote
- Lists last 5 commits
- Reports uncommitted changes count
- Provides immediate project context to Claude

**Triggers:** At session start

---

### User Prompt Hooks

#### 6. **prompt-context-check.sh** (UserPromptSubmit)
Monitors context usage and warns when approaching limits.

**Features:**
- Estimates token usage from transcript size
- Warns at 75% of context limit (150K tokens)
- Critical alert at 90% of context limit (180K tokens)
- Suggests `/clear` or conversation compaction

**Triggers:** When user submits a prompt

---

## Project-Specific Hooks

The hooks above are **universal** - they work across all projects without modification. For **project-specific** functionality (like auto-formatting, test runners, or custom linting), you should create hooks in your project's `.claude/hooks/` directory.

**Why keep project-specific hooks separate?**
- Different projects use different formatters, test frameworks, and conventions
- Project-specific hooks require project dependencies and configuration
- Universal hooks (in dotfiles) provide safety and quality checks everywhere
- Project hooks (in `.claude/`) add project-specific validations and automation

**See [PROJECT_LEVEL_TEMPLATES.md](PROJECT_LEVEL_TEMPLATES.md) for:**
- Comprehensive templates for formatters, test runners, linters, and more
- Guidance on when to use project-level vs. dotfiles hooks
- Best practices for creating custom hooks
- Examples of combining universal and project-specific hooks

---

## Hook Configuration

All hooks are configured in `~/.claude/settings.json` and are enabled by default. Hooks have reasonable timeouts to prevent blocking your workflow.

### Disabling Hooks

To disable a specific hook, edit `~/.claude/settings.json` and remove or comment out the corresponding hook entry.

### Customizing Hooks

All hook scripts are in `~/.claude/hooks/` and can be edited to customize behavior. After editing, no restart is needed - changes take effect immediately.

## Troubleshooting

### Hook Not Running
1. Check hook is executable: `ls -la ~/.claude/hooks/`
2. Test hook manually: `echo '{}' | ~/.claude/hooks/hook-name.sh`
3. Check Claude Code logs: `~/.claude/debug/`

### Hook Timing Out
Increase timeout in `settings.json`:
```json
{
  "timeout": 30  // Increase value
}
```

### Hook Errors
Hooks that exit with non-zero codes (except exit code 2 for deny) are logged but don't block operations.

## Best Practices

1. **Keep hooks fast** - They run on every tool use
2. **Exit 0 for success** - Let normal flow continue
3. **Exit 2 to block** - Shows stderr to Claude as denial reason
4. **Use JSON output** - For structured responses (PreToolUse approval decisions)
5. **Test thoroughly** - Broken hooks can disrupt workflow

## Resources

- [Claude Code Hooks Documentation](https://docs.claude.com/en/docs/claude-code/hooks)
- [Conventional Commits Specification](https://www.conventionalcommits.org/)
