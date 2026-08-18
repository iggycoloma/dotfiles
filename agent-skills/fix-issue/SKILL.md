---
name: fix-issue
description: |
  Analyze and fix a filed issue or ticket end-to-end (investigate, reproduce,
  fix, test, and prepare the repository/forge handoff). Tracker-agnostic: GitHub and
  GitLab issues via gh/glab, Linear or another tracker via its configured MCP
  server. TRIGGER when the user references a filed issue or ticket -- #NNN, an
  issue URL, a ticket key like ENG-123, or pasted `gh issue view` /
  `glab issue view` output -- and asks to address it. SKIP for bugs the user
  is reporting in chat without a filed issue (use debug instead) or when they
  only want investigation without implementation.
---

You are analyzing and fixing a filed issue or ticket.

## Process

1. **Resolve the tracker and fetch the issue**. The target may be a bare
   number, a URL, or a ticket key -- route on its shape:
   - GitHub URL, or bare `#NNN` with a GitHub remote (`git remote get-url origin`):
     fetch it with `gh issue view`.
   - GitLab URL, or bare `#NNN` with a GitLab remote: fetch it with `glab issue view`.
   - Ticket key (`ENG-123`) or a non-forge tracker URL: use that tracker's MCP
     server if one is configured. If none is, say so and ask the user to paste
     the ticket -- never install or configure an MCP server for this.

2. **Normalize to common concepts**, whatever the source calls them:
   - Identifier and title
   - Problem statement; steps to reproduce (if bug)
   - Expected vs actual behavior; error messages or logs
   - Acceptance criteria and linked discussion, if present

3. **Investigate**:
   - Search the codebase for relevant terms (Grep tool, or `rg` / `sg`)
   - Check recent changes that might have caused it:
     ```bash
     git log --oneline --all --grep="related_term"
     ```
   - Look for similar resolved issues in the same tracker (e.g.
     `gh issue list --state closed --search "keywords"`, the glab equivalent,
     or the MCP search)

4. **Reproduce** (if bug):
   - Try to recreate the issue locally
   - Confirm the problem exists

5. **Develop solution**:
   - Identify root cause
   - Implement minimal fix
   - Add tests to prevent regression
   - Verify the fix resolves the issue

6. **Branch and commit**. Derive a slug from the identifier -- if the tracker
   suggests a branch name (Linear does), prefer it:
   ```bash
   git checkout -b fix/<identifier-slug>
   git commit -m "fix: <description> (<identifier>)"
   ```

7. **Draft the PR/MR** following `create-pr`: compose the title and body,
   reference the issue the way its tracker autolinks (`Fixes #NNN` on the
   forges; the ticket key, e.g. `Fixes ENG-123`, for Linear), show the create
   command, and stop. Tracker writes -- status changes, comments -- are
   likewise drafted for approval, never executed directly.

## Output Format

### Issue Analysis
- <identifier>: [Title]
- Type: Bug / Feature Request / Enhancement

### Root Cause
[Explanation of what's wrong]

### Solution
[Description of the fix]

### Changes Made
- File 1: [Description]
- File 2: [Description]

### Testing
- [How to verify the fix works]

### Handoff
- Branch: fix/<identifier-slug>
- PR/MR: [drafted title and body, plus the command to create it]

Follow the active agent's publication policy for branch creation, commits, pushes, tracker writes, and PR/MR creation.
