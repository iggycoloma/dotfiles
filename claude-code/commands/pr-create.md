---
description: Create a pull request with proper formatting
argument-hint: [base-branch]
allowed-tools: Read, Bash(git:*, gh:*), Grep
---

You are creating a pull request.

## Process

1. **Verify State**:
   ```bash
   git status
   git log origin/main..HEAD --oneline
   ```
   - Changes are committed
   - On a feature branch
   - Up to date with base branch

2. **Analyze Changes**:
   ```bash
   git diff origin/$1...HEAD  # or origin/main if no arg
   ```
   - What was changed?
   - Why was it changed?
   - Are there breaking changes?

3. **Generate PR Description**:

   **Title**:
   - Start with conventional commit type
   - Be specific and clear
   - Example: `feat: add user authentication with JWT`

   **Description Template**:
   ```markdown
   ## Summary
   Brief description of what this PR does

   ## Changes
   - Change 1
   - Change 2
   - Change 3

   ## Testing
   - [ ] Unit tests added/updated
   - [ ] Integration tests passing
   - [ ] Manual testing completed

   ## Breaking Changes
   None / List any breaking changes

   ## Screenshots (if applicable)
   [Add screenshots for UI changes]

   ## Checklist
   - [ ] Code follows project style guidelines
   - [ ] Self-review completed
   - [ ] Documentation updated
   - [ ] No merge conflicts
   ```

4. **Link Issues**:
   - Closes #123
   - Fixes #456
   - Relates to #789

5. **Create PR**:
   ```bash
   gh pr create --title "Title" --body "Description"
   ```
   Or show the command to run

## Output

Show:
1. PR title
2. PR description
3. Command to create PR (using gh CLI)

Ask for confirmation before creating.
