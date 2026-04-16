# Plan: Ralph-Style Workflow + Git Worktree Infrastructure

## Context

The dotfiles repo has a solid Claude Code foundation (hooks, agents, pipeline, permissions, CLAUDE.md). The next step is enabling unattended autonomous workflows (Ralph-style loops) and parallel agent execution via git worktrees. This requires new scripts, templates, permission profiles, and shell integration.

## Current State

**Have:** Hooks, 4-stage pipeline agents, 16 slash commands, permissions baseline, Pushover notifications, statusline
**Missing:** Headless permission mode, worktree management, loop runner, PRD templates, MCP servers, cost guardrails

## Part 1: Worktree Management

### Shell functions (`shell/functions.sh`)

```bash
# Launch Claude Code in a new worktree
ccw() {
  local branch="${1:?Usage: ccw <branch-name> [prompt]}"
  shift
  claude --worktree "$branch" "$@"
}

# List active Claude worktrees
ccwls() {
  git worktree list
}

# Clean up merged/stale worktrees
ccwclean() {
  git worktree prune
  # List worktrees, prompt before removing
}
```

### Shell aliases (`shell/aliases.sh`)

```bash
alias ccw='ccw'           # claude worktree
alias ccwls='ccwls'       # list worktrees
alias ccwclean='ccwclean' # prune worktrees
```

## Part 2: Ralph Loop Runner

### New file: `claude-code/scripts/ralph.sh`

Core loop script with safety guardrails:

```bash
#!/usr/bin/env bash
# Ralph-style autonomous loop for Claude Code
# Usage: ralph.sh [--max-iterations N] [--worktree branch] PROMPT_FILE

MAX_ITERATIONS=20          # Default cap (override with --max-iterations)
WORKTREE=""                # Optional worktree branch
PROMPT_FILE=""             # Path to PROMPT.md
PROGRESS_FILE="progress.txt"
ITERATION=0

# Parse args...

# Main loop
while [[ $ITERATION -lt $MAX_ITERATIONS ]]; do
    ((ITERATION++))
    echo "[Ralph] Iteration $ITERATION/$MAX_ITERATIONS"

    # Run Claude headless with prompt
    if [[ -n "$WORKTREE" ]]; then
        cat "$PROMPT_FILE" | claude -p --worktree "$WORKTREE" --permission-mode acceptEdits
    else
        cat "$PROMPT_FILE" | claude -p --permission-mode acceptEdits
    fi

    # Check for completion signal in progress file
    if grep -q "COMPLETE" "$PROGRESS_FILE" 2>/dev/null; then
        echo "[Ralph] All tasks complete after $ITERATION iterations"
        # Send Pushover notification
        break
    fi

    # Brief pause between iterations
    sleep 2
done

if [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
    echo "[Ralph] Hit max iterations ($MAX_ITERATIONS)"
    # Send Pushover notification with warning
fi
```

### Shell alias

```bash
alias ralph='bash ~/.claude/scripts/ralph.sh'
```

## Part 3: PRD/Progress Templates

### New file: `claude-code/templates/PROMPT.md`

The prompt fed to Claude each iteration:

```markdown
# Task Instructions

Read PRD.md for the full requirements. Read progress.txt for current state.

## Rules
1. Pick the NEXT incomplete task from PRD.md
2. Implement exactly ONE task per iteration
3. Run tests/linters to validate
4. Commit changes with conventional commit message
5. Update progress.txt: mark task complete, note what was done, record any learnings
6. If ALL tasks are complete, write "COMPLETE" to progress.txt

## Files
- PRD.md -- requirements and task checklist
- progress.txt -- iteration history and current state
- CLAUDE.md -- project instructions (if exists)
```

### New file: `claude-code/templates/PRD.md`

```markdown
# Feature: [Name]

## Overview
[Brief description]

## Tasks
- [ ] Task 1: [description]
- [ ] Task 2: [description]
- [ ] Task 3: [description]

## Acceptance Criteria
- [criterion 1]
- [criterion 2]

## Out of Scope
- [exclusion 1]
```

### New file: `claude-code/templates/progress.txt`

```
# Progress Log
# Each iteration appends its status here.
# Write "COMPLETE" when all PRD tasks are done.
```

## Part 4: Headless Permission Profile

### Approach: separate settings for headless mode

The current `settings.json` is tuned for interactive use (prompts for destructive ops). Headless Ralph needs broader permissions since there's no human to approve.

**Option A (recommended):** Use `--permission-mode acceptEdits` flag in the ralph script. This accepts all file edits but still prompts for Bash commands not in the allow list. The existing allow list is broad enough for most dev work.

**Option B:** Create a `settings.headless.json` with a more permissive allow list that gets swapped in during Ralph runs. More complex, harder to maintain.

Recommend Option A -- the `acceptEdits` flag plus the existing Bash allow list should cover most cases. If specific commands keep blocking, add them to the allow list in settings.json.

## Part 5: MCP Server Configuration

### GitHub MCP Server

Most valuable for Ralph workflows -- lets Claude read issues, PR comments, CI status without shelling out to `gh`.

```bash
claude mcp add github -- npx -y @anthropic-ai/github-mcp-server
```

This writes to `~/.claude/settings.json` or `~/.claude/settings.local.json`. Since MCP config is machine-specific (requires auth tokens), it belongs in `settings.local.json` not the git-tracked `settings.json`.

### Documentation

Add MCP setup instructions to README.md or a new `claude-code/MCP.md` so the user can configure it per-machine.

## Part 6: Cost/Iteration Guardrails

Built into `ralph.sh`:
- `--max-iterations N` flag (default: 20)
- Pushover notification on completion or max-iterations-hit
- Elapsed time tracking per iteration
- Optional: `--max-cost` flag that checks `claude usage` between iterations (if the CLI supports it)

## Part 7: Multi-Worktree Orchestration

### New file: `claude-code/scripts/ralph-parallel.sh`

Launches N Ralph loops on separate worktrees:

```bash
#!/usr/bin/env bash
# Usage: ralph-parallel.sh feature-a:PRD-a.md feature-b:PRD-b.md ...

for spec in "$@"; do
    branch="${spec%%:*}"
    prd="${spec##*:}"
    echo "[Ralph] Starting worktree: $branch with PRD: $prd"
    ralph.sh --worktree "$branch" --max-iterations 20 "$prd" &
done

echo "[Ralph] $# parallel loops running. Use 'ccwls' to monitor."
wait
echo "[Ralph] All loops complete."
```

## File Summary

| File | Action |
|------|--------|
| `shell/functions.sh` | Add ccw, ccwls, ccwclean functions |
| `shell/aliases.sh` | Add ralph, ccw aliases |
| `claude-code/scripts/ralph.sh` | New -- loop runner with guardrails |
| `claude-code/scripts/ralph-parallel.sh` | New -- multi-worktree orchestration |
| `claude-code/templates/PROMPT.md` | New -- iteration prompt template |
| `claude-code/templates/PRD.md` | New -- requirements template |
| `claude-code/templates/progress.txt` | New -- progress log seed |
| `bootstrap/symlinks.sh` | Add symlinks for scripts/ and templates/ dirs |
| `README.md` | Document Ralph workflow and worktree usage |

## Verification

```bash
# Worktree functions
ccw test-feature  # launches Claude in worktree
ccwls             # lists worktrees
ccwclean          # prunes stale worktrees

# Single Ralph loop
ralph.sh --max-iterations 5 templates/PROMPT.md

# Parallel loops
ralph-parallel.sh feature-a:PRD-a.md feature-b:PRD-b.md

# Notifications fire on completion
```

## Open Questions

1. Should ralph.sh use Docker sandboxing (like Huntley's original) or trust the permission hooks?
2. Should we install the ralph-wiggum plugin (`/plugin install ralph-wiggum`) instead of/alongside the DIY script?
3. What MCP servers beyond GitHub are worth configuring? (Context7, Playwright, etc.)
4. Should worktree cleanup happen automatically after merge, or always manual?
