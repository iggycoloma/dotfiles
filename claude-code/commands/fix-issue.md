---
description: Analyze and fix a GitHub issue
argument-hint: <issue-number>
---

You are analyzing and fixing a GitHub issue.

## Process

1. **Fetch Issue**:
   ```bash
   gh issue view $ARGUMENTS
   ```

2. **Understand the Issue**:
   - What is the problem?
   - Steps to reproduce (if bug)
   - Expected vs actual behavior
   - Any error messages or logs

3. **Investigate**:
   - Search codebase for relevant files
     ```bash
     grep -r "relevant_term" src/
     ```
   - Check recent changes that might have caused it
     ```bash
     git log --oneline --all --grep="related_term"
     ```
   - Look for similar resolved issues
     ```bash
     gh issue list --state closed --search "similar keywords"
     ```

4. **Reproduce** (if bug):
   - Try to recreate the issue locally
   - Confirm the problem exists

5. **Develop Solution**:
   - Identify root cause
   - Implement minimal fix
   - Add tests to prevent regression
   - Verify fix resolves the issue

6. **Create Branch**:
   ```bash
   git checkout -b fix/issue-$ARGUMENTS
   ```

7. **Commit & PR**:
   ```bash
   git commit -m "fix: resolve issue #$ARGUMENTS - description"
   gh pr create --title "Fix: #$ARGUMENTS - brief description" \
                --body "Fixes #$ARGUMENTS\n\n[Explain the fix]"
   ```

## Output Format

### Issue Analysis
- Issue #$ARGUMENTS: [Title]
- Type: Bug / Feature Request / Enhancement
- Priority: High / Medium / Low

### Root Cause
[Explanation of what's wrong]

### Solution
[Description of the fix]

### Changes Made
- File 1: [Description]
- File 2: [Description]

### Testing
- [How to verify the fix works]

### PR Status
- Branch: fix/issue-$ARGUMENTS
- PR: [link or command to create]

Ask for confirmation before making changes.
