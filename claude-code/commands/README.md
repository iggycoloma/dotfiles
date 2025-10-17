# Claude Code Slash Commands

A curated collection of production-ready slash commands for Claude Code, based on community best practices from Reddit, GitHub, and real-world usage.

## What Are Slash Commands?

Slash commands are **reusable prompt templates** stored as Markdown files that you invoke with `/command-name`. They help you:

- **Save tokens**: 20%+ reduction reported by converting repeated workflows to commands
- **Work faster**: Multi-step processes → single command
- **Stay consistent**: Same workflow every time
- **Share with team**: Commands sync via git

## Commands vs. Agents

| Feature | Commands | Agents |
|---------|----------|--------|
| **Best for** | Daily workflows | Specialized tasks |
| **Context** | Main conversation | Isolated window |
| **Complexity** | Simple-Medium | Medium-Complex |
| **Invocation** | `/command-name` | Automatic/on-demand |

**Use commands when**:
- You do it 5+ times a day
- It's a simple prompt template
- You want quick shortcuts
- Context in main conversation is OK

**Use agents when**:
- Complex multi-step workflows
- Need isolated context
- Deep research/analysis required

## Command Collection

### 📅 Phase 1: Daily Development (Use These First)

These are your most-used commands. Start here.

#### `/commit [message]`
**Purpose**: Smart conventional commit workflow
**What it does**:
- Analyzes `git diff --staged`
- Determines commit type (feat, fix, docs, etc.)
- Generates conventional commit message
- Creates commit

**Usage**:
```bash
/commit
# Or with custom message:
/commit "feat: add user authentication"
```

**Frequency**: 10-20x per day

---

#### `/review [file]`
**Purpose**: Quick code review
**What it does**:
- Reviews staged changes or specified file
- Checks quality, security, performance
- Provides prioritized feedback (Critical/Suggestions/Good)

**Usage**:
```bash
/review
# Or specific file:
/review src/auth.ts
```

**Frequency**: Before every commit

---

####

 `/debug [error]`
**Purpose**: Systematic error analysis
**What it does**:
- Gathers error information
- Forms hypotheses
- Identifies root cause
- Proposes minimal fix

**Usage**:
```bash
/debug "TypeError: Cannot read property 'name' of undefined"
```

**Frequency**: When bugs appear

---

#### `/test [file]`
**Purpose**: Generate comprehensive test cases
**What it does**:
- Detects test framework
- Generates unit tests
- Covers happy path, edge cases, errors

**Usage**:
```bash
/test
# Or specific file:
/test src/utils/validation.ts
```

**Frequency**: For new features

---

#### `/refactor [file]`
**Purpose**: Clean up code smells
**What it does**:
- Identifies code smells
- Extracts functions, improves naming
- Removes duplication
- Makes incremental improvements

**Usage**:
```bash
/refactor src/legacy-module.js
```

**Frequency**: Regular maintenance

---

### 📚 Phase 2: Documentation & Quality

Add these once Phase 1 is working well.

#### `/docs [files]`
**Purpose**: Update documentation
**What it does**:
- Syncs docs with code changes
- Updates README, API docs, comments
- Maintains CHANGELOG

**Usage**:
```bash
/docs
# Or specific:
/docs src/api/*.ts
```

---

#### `/changelog [from] [to]`
**Purpose**: Generate changelog
**What it does**:
- Analyzes git commits
- Categorizes changes (Added/Changed/Fixed)
- Follows Keep a Changelog format

**Usage**:
```bash
/changelog
# Or between tags:
/changelog v1.0.0 v1.1.0
```

---

#### `/security-audit [dir]`
**Purpose**: Security vulnerability scan
**What it does**:
- Checks for exposed secrets
- Scans dependencies for CVEs
- Validates input handling
- Reviews auth/authz
- OWASP Top 10 check

**Usage**:
```bash
/security-audit
# Or specific directory:
/security-audit src/api/
```

---

#### `/optimize [file]`
**Purpose**: Performance analysis
**What it does**:
- Identifies bottlenecks
- Analyzes algorithm complexity
- Suggests caching strategies
- Proposes database optimizations

**Usage**:
```bash
/optimize src/data-processing.ts
```

---

#### `/dependencies`
**Purpose**: Dependency management
**What it does**:
- Checks for updates
- Scans security vulnerabilities
- Categorizes by risk (patch/minor/major)
- Provides update commands

**Usage**:
```bash
/dependencies
```

**Frequency**: Monthly or before releases

---

#### `/pr-create [base-branch]`
**Purpose**: Create pull request
**What it does**:
- Analyzes changes
- Generates PR title and description
- Creates checklist
- Links issues

**Usage**:
```bash
/pr-create
# Or specify base:
/pr-create develop
```

---

### 🚀 Phase 3: Advanced Workflows

Add these for specialized needs.

#### `/context-prime`
**Purpose**: Initialize session with project context
**What it does**:
- Loads project structure
- Detects tech stack
- Reads documentation
- Shows recent activity

**Usage**:
```bash
/context-prime
```

**When**: Start of each new session

---

#### `/feature-spec <name>`
**Purpose**: Generate feature specification
**What it does**:
- Creates comprehensive spec document
- User stories with acceptance criteria
- Defines requirements, API, data model
- Identifies dependencies

**Usage**:
```bash
/feature-spec user-authentication
```

---

#### `/deploy-checklist`
**Purpose**: Pre-deployment verification
**What it does**:
- Validates code quality
- Checks security
- Verifies performance
- Reviews documentation
- Confirms monitoring

**Usage**:
```bash
/deploy-checklist
```

**When**: Before every deployment

---

#### `/fix-issue <number>`
**Purpose**: Fix GitHub issue
**What it does**:
- Fetches issue details
- Investigates root cause
- Implements fix
- Creates PR with proper linking

**Usage**:
```bash
/fix-issue 123
```

---

## Quick Reference

| Command | Use When | Frequency |
|---------|----------|-----------|
| `/commit` | Making commits | 10-20x/day |
| `/review` | Before committing | Every commit |
| `/debug` | Encountering errors | As needed |
| `/test` | Writing new code | Per feature |
| `/refactor` | Code needs cleanup | Weekly |
| `/docs` | Code changes made | Per feature |
| `/changelog` | Preparing release | Per release |
| `/security-audit` | Before release | Pre-release |
| `/optimize` | Performance issues | As needed |
| `/dependencies` | Maintenance | Monthly |
| `/pr-create` | Creating PRs | Per feature |
| `/context-prime` | New session | Per session |
| `/feature-spec` | Planning features | Per feature |
| `/deploy-checklist` | Before deploy | Per deploy |
| `/fix-issue` | Fixing bugs | As needed |

## Getting Started

### Week 1: Phase 1 Only
Start with the 5 daily commands:
```bash
/commit    # Use for every commit
/review    # Before each commit
/debug     # When bugs appear
/test      # For new code
/refactor  # Weekly cleanup
```

### Week 2-3: Add Phase 2
Once comfortable, add documentation commands:
```bash
/docs
/changelog
/security-audit
/optimize
/dependencies
/pr-create
```

### Month 2+: Phase 3
Add advanced workflows as needed:
```bash
/context-prime
/feature-spec
/deploy-checklist
/fix-issue
```

## Context Optimization

### The Pattern

**Before** (Context-Heavy):
```markdown
# CLAUDE.md (uses permanent context)
- How to commit
- How to review code
- How to write tests
- How to update docs
- How to create PRs
(All instructions always loaded = high token usage)
```

**After** (Context-Optimized):
```markdown
# CLAUDE.md (minimal permanent context)
- Project structure
- Coding standards
- Architecture patterns

# Commands (on-demand context)
- /commit
- /review
- /test
- /docs
- /pr-create
(Instructions only loaded when invoked = 20-30% token reduction)
```

### Best Practice

1. **Keep in CLAUDE.md**: Project-specific patterns, standards, structure
2. **Move to commands**: Workflows, checklists, repetitive tasks
3. **Result**: More available context for actual coding

## Command Syntax

### Basic Command
```markdown
---
description: Brief description shown in /help
---

Your prompt here.
```

### With Arguments
```markdown
---
description: Command with parameters
argument-hint: <required> [optional]
---

Process $ARGUMENTS here.
Or use $1, $2, $3 for specific args.
```

### Advanced (With Tools/Model)
```markdown
---
description: Advanced command
allowed-tools: Read, Grep, Bash
model: sonnet
---

Your prompt here with tool restrictions.
```

## Customization

### Modify a Command

1. Edit the command file: `claude-code/commands/command-name.md`
2. Changes take effect immediately
3. No restart needed

### Create Your Own

```markdown
---
description: What this command does
argument-hint: [optional params]
---

Your custom prompt here.
Use $ARGUMENTS for all args.
Use $1, $2 for specific positional args.
```

Save to `claude-code/commands/your-command.md`

## Tips & Tricks

1. **Use Tab Completion**: Type `/` and press Tab to see all commands
2. **Check `/help`**: See all available commands with descriptions
3. **Start Small**: Begin with 3-5 commands you'll actually use
4. **Iterate**: Add more as you identify bottlenecks
5. **Share with Team**: Commands in repo = team consistency

## Community Resources

- [Awesome Claude Code](https://github.com/hesreallyhim/awesome-claude-code) - Curated commands
- [Claude Code Docs](https://docs.claude.com/en/docs/claude-code/slash-commands) - Official documentation
- [wshobson/commands](https://github.com/wshobson/commands) - 57 production commands

## Troubleshooting

### Command Not Found
- Check file is in `claude-code/commands/`
- Restart Claude Code session
- Verify markdown syntax

### Command Not Working
- Check argument syntax in frontmatter
- Test prompt manually first
- Verify bash commands have proper syntax

### Too Many Commands
- Start with Phase 1 only
- Add more gradually
- Remove commands you don't use

## Success Metrics

Track your improvements:
- **Token usage**: Should decrease 20-30%
- **Commit consistency**: All commits follow conventions
- **Code quality**: Fewer review comments
- **Speed**: Faster daily workflows
- **Documentation**: Stays current automatically

## Summary

**Start with**: `/commit`, `/review`, `/debug`, `/test`, `/refactor` (Phase 1)
**Add next**: Documentation & quality commands (Phase 2)
**Advanced**: Workflow automation (Phase 3)

**Expected benefit**: 20-30% context reduction, faster workflows, team consistency.

Happy coding! 🚀
