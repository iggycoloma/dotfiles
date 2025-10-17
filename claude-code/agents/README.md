

# Claude Code Agents

This directory contains a comprehensive collection of specialized agents for Claude Code, designed to maximize productivity while optimizing context usage.

## Philosophy

These agents follow community-validated best practices:
- **Start small, scale smart**: Begin with Phase 1, add more as needed
- **Context isolation**: Each agent operates in its own context window
- **Explicit tool permissions**: Security through minimal tool access
- **Progressive enhancement**: Add agents based on actual bottlenecks

## Agent Portfolio

### 📊 Phase 1: Core Quality (Start Here)

These are your foundational agents. Start with these two and use them for 1-2 weeks before adding more.

#### 1. code-reviewer
**File**: `code-reviewer.md`
**Activation**: Proactive (after code changes)
**Tools**: Read, Grep, Glob, Bash
**Model**: inherit

Automatically reviews code for quality, security, and maintainability after you write or modify code.

**What it checks:**
- Code readability and naming
- Security vulnerabilities
- Performance issues
- Test coverage
- Best practices

**When to use**: Runs automatically after Write/Edit operations

---

#### 2. debugger
**File**: `debugger.md`
**Activation**: On-demand (when issues arise)
**Tools**: Read, Edit, Bash, Grep, Glob
**Model**: inherit

Systematic debugging specialist that finds root causes, not just symptoms.

**What it does:**
- Analyzes error messages and stack traces
- Forms and tests hypotheses
- Implements minimal fixes
- Verifies solutions work

**When to use**: When you encounter errors, test failures, or unexpected behavior

---

### 📈 Phase 2: Quality Enhancement (Add After Phase 1)

Add these agents once Phase 1 is working well and you've identified the need.

#### 3. test-writer
**File**: `test-writer.md`
**Activation**: On-demand
**Tools**: Read, Write, Bash
**Model**: inherit

Generates comprehensive test suites for new or modified code.

**What it creates:**
- Unit tests for business logic
- Integration tests for APIs
- E2E tests for critical flows
- Covers happy path + edge cases

**When to use**: Ask explicitly: "Write tests for this feature"

---

#### 4. doc-writer
**File**: `doc-writer.md`
**Activation**: On-demand
**Tools**: Read, Write, Grep, Glob
**Model**: inherit

Keeps documentation synchronized with code changes.

**What it updates:**
- README files
- API documentation
- Code comments and docstrings
- Architecture docs

**When to use**: "Update documentation for this change"

---

#### 5. refactor-specialist
**File**: `refactor-specialist.md`
**Activation**: Explicit only
**Tools**: Read, Edit, Grep, Glob
**Model**: inherit

Safe, methodical code refactoring to improve structure and maintainability.

**What it does:**
- Identifies code smells
- Extracts functions
- Removes duplication
- Simplifies conditionals

**When to use**: "Refactor this code" or "Clean up this module"

---

### 🔒 Phase 3: Advanced Operations (Optional)

Add these for specialized needs.

#### 6. security-auditor
**File**: `security-auditor.md`
**Activation**: Explicit only
**Tools**: Read, Grep, Glob
**Model**: inherit

Comprehensive security analysis and vulnerability scanning.

**What it checks:**
- Authentication/authorization
- Input validation
- SQL injection, XSS, CSRF
- Exposed secrets
- OWASP Top 10

**When to use**: Before releases or: "Run security audit"

---

#### 7. performance-optimizer
**File**: `performance-optimizer.md`
**Activation**: Explicit only
**Tools**: Read, Edit, Bash, Grep
**Model**: inherit

Identifies bottlenecks and implements performance improvements.

**What it optimizes:**
- Algorithm complexity
- Database queries
- Caching strategies
- Memory usage

**When to use**: "Optimize performance" or when you have measurable slowness

---

#### 8. dependency-manager
**File**: `dependency-manager.md`
**Activation**: Explicit only
**Tools**: Read, Edit, Bash
**Model**: haiku (fast & cheap)

Manages package updates, security patches, and dependency conflicts.

**What it handles:**
- Dependency updates
- Security vulnerability fixes
- Version conflict resolution
- Compatibility checking

**When to use**: "Update dependencies" or "Check for security vulnerabilities"

---

### 🔄 Alternative: Pipeline Workflow

For teams or structured feature development, use these pipeline agents instead of (or in addition to) individual agents.

#### 9. pm-spec (Stage 1)
**File**: `pm-spec.md`
**Tools**: Read, Grep, Write
**Model**: inherit

Gathers requirements and writes specifications.

**Output**: Specification document → Status: `READY_FOR_ARCH`

---

#### 10. architect-review (Stage 2)
**File**: `architect-review.md`
**Tools**: Read, Grep, Glob
**Model**: inherit

Validates design and produces Architecture Decision Records.

**Output**: ADR document → Status: `READY_FOR_BUILD`

---

#### 11. implementer-tester (Stage 3)
**File**: `implementer-tester.md`
**Tools**: Read, Write, Edit, Bash
**Model**: inherit

Implements features and writes comprehensive tests.

**Output**: Implemented feature → Status: `READY_FOR_QA`

---

#### 12. qa-reviewer (Stage 4)
**File**: `qa-reviewer.md`
**Tools**: Read, Bash, Grep, Glob
**Model**: inherit

Comprehensive QA validation and release approval.

**Output**: QA report → Status: `DONE` or `NEEDS_WORK`

---

## Usage Guide

### Getting Started

**Week 1-2: Phase 1 Only**
```bash
# Use these agents naturally in your workflow
# code-reviewer will activate automatically after edits
# debugger only when you need it
```

**Week 3-4: Add Phase 2**
```bash
# If you find yourself wishing for tests: add test-writer
# If docs are falling behind: add doc-writer
# If code is getting messy: add refactor-specialist
```

**Month 2+: Phase 3 as Needed**
```bash
# Before releases: security-auditor
# When slow: performance-optimizer
# Monthly: dependency-manager
```

### Invoking Agents

**Automatic (Proactive Agents)**
```
# These run automatically based on their description
# code-reviewer: Runs after you write/edit code
```

**Natural Language (On-Demand Agents)**
```
# Just mention what you need
"Debug this error"  → debugger activates
"Write tests"       → test-writer activates
"Update docs"       → doc-writer activates
```

**Explicit Request (Manual Agents)**
```
# Be specific
"Run security audit"          → security-auditor
"Use the debugger agent"      → debugger
"Invoke dependency-manager"   → dependency-manager
```

### Pipeline Workflow Usage

For structured feature development:

```bash
# Step 1: Requirements
"Let's spec out user authentication feature"
→ pm-spec creates specification

# Step 2: Architecture
"Review the auth spec"
→ architect-review creates ADR

# Step 3: Implementation
"Build the auth feature"
→ implementer-tester implements and tests

# Step 4: QA
"QA review the auth feature"
→ qa-reviewer validates and approves
```

## Agent Comparison

| Agent | When | How Often | Context Cost |
|-------|------|-----------|--------------|
| code-reviewer | After edits | Frequent | Medium |
| debugger | When bugs appear | Occasional | Medium |
| test-writer | For new features | Regular | Low-Medium |
| doc-writer | When docs needed | Regular | Low |
| refactor-specialist | Code cleanup | Occasional | Medium |
| security-auditor | Before releases | Rare | Low |
| performance-optimizer | Performance issues | Rare | Medium |
| dependency-manager | Monthly updates | Rare | Low |
| pm-spec | New features | As needed | Low |
| architect-review | New features | As needed | Low |
| implementer-tester | New features | As needed | High |
| qa-reviewer | Feature complete | As needed | Medium |

## Context Optimization

### How Agents Save Context

**Without Agents** (Traditional):
```
Main context: 150K tokens (approaching limit)
- All planning, implementation, testing, review in one conversation
- Can't fit more complex features
```

**With Agents** (Optimized):
```
Main context: 20K tokens (high-level coordination)
├── code-reviewer: 10K tokens (isolated review)
├── test-writer: 15K tokens (isolated test generation)
└── debugger: 8K tokens (isolated debugging)

Total capacity: 3-5x more effective work
```

### Best Practices for Context Management

1. **Use agents for specialized tasks**: Don't pollute main conversation
2. **Prefer on-demand over proactive**: Control when agents run
3. **Pipeline for complex features**: Isolate each phase
4. **Monitor context usage**: Use the prompt-context-check hook

## Configuration

### Model Selection

**inherit** (Default - Recommended)
- Agent uses whatever model you started with
- Flexible: Control cost at session start

**sonnet** (Explicit)
- Always use Sonnet regardless of main session
- Good for: Most coding tasks

**haiku** (Fast & Cheap)
- Always use Haiku
- Good for: dependency-manager, simple tasks

**opus** (Maximum Quality)
- Always use Opus
- Good for: Critical security audits

### Tool Restrictions

All agents have **explicit tool lists** for security:
- Never grant more tools than needed
- Read-only agents can't modify code
- Write agents can't execute arbitrary bash

## Customization

### Modify an Agent

1. Edit the agent file: `claude-code/agents/agent-name.md`
2. Changes take effect immediately (no restart needed)
3. Adjust description to change activation behavior
4. Modify tools list to change permissions

### Create Your Own Agent

```markdown
---
name: my-custom-agent
description: When to invoke this agent (be specific!)
tools: Read, Write  # Only what's needed
model: inherit      # Or sonnet, haiku, opus
---

Your system prompt here explaining:
- What this agent does
- How it should work
- Output format
- Best practices
```

## Troubleshooting

### Agent Not Activating

**Problem**: Agent doesn't run when expected

**Solutions**:
- Check description field - be more specific about when to use
- Try explicit invocation: "Use the [agent-name] agent"
- Verify agent file is in `~/.claude/agents/`

### Agent Doing Too Much

**Problem**: Agent runs too often

**Solutions**:
- Change description from "proactive" to "explicit"
- Add qualifiers: "only when explicitly requested"
- Move from Phase 1 to Phase 2/3

### Context Still Running Out

**Problem**: Hitting context limits despite agents

**Solutions**:
- Use more agents (isolate more tasks)
- Switch to pipeline workflow for features
- Use haiku model for simple agents
- Start fresh conversations more often

## Migration from No Agents

If you're currently not using agents:

**Week 1**: Add code-reviewer only
- Get comfortable with automatic reviews
- Learn to trust the feedback

**Week 2**: Add debugger
- Use when you encounter bugs
- Compare to manual debugging

**Week 3-4**: Add 1-2 Phase 2 agents
- Based on your biggest pain points
- Test generation? → test-writer
- Documentation lag? → doc-writer

**Month 2**: Evaluate and add Phase 3
- Security concerns? → security-auditor
- Performance issues? → performance-optimizer

## Community Resources

- [Claude Code Docs](https://docs.claude.com/en/docs/claude-code/sub-agents)
- [ClaudeLog Best Practices](https://claudelog.com/mechanics/custom-agents/)
- [Reddit Community](https://reddit.com/r/ClaudeCode) (unofficial)

## Success Metrics

Track your improvement:
- Context usage per feature (should decrease)
- Code review findings (should improve code quality)
- Test coverage (should increase)
- Bug rate (should decrease)
- Documentation freshness (should improve)

## Summary

**Start with**: code-reviewer + debugger (Phase 1)
**Add next**: Based on bottlenecks (Phase 2)
**Advanced**: Security, performance, dependencies (Phase 3)
**Alternative**: Pipeline workflow for structured development

**Expected benefit**: 3-5x effective context capacity, higher code quality, better documentation.

Happy coding! 🚀
