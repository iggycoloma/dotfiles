---
description: |
  Draft a pull request (GitHub) or merge request (GitLab) with proper
  formatting. Detects the forge from the git remote, composes the title and
  body, and hands them over -- creation runs only with explicit approval.
argument-hint: "[base-branch]"
allowed-tools: Read, Grep, Bash(git:*), Bash(gh:*), Bash(glab:*)
---

You are drafting a pull request or merge request.

## Process

1. **Detect the forge**:
   ```bash
   git remote get-url origin
   ```
   - GitHub host -> `gh`, "pull request", `gh pr create`
   - GitLab host (gitlab.com or self-hosted) -> `glab`, "merge request", `glab mr create`
   - Anything else -> compose the title and body anyway and say no forge CLI is configured for that host

2. **Verify state**:
   ```bash
   git status
   git log origin/main..HEAD --oneline
   ```
   - Changes are committed
   - On a feature branch
   - Up to date with the base branch

   The base is `$1` if given; otherwise determine the default branch with
   `git symbolic-ref refs/remotes/origin/HEAD` rather than assuming `main`.

3. **Analyze changes**:
   ```bash
   git diff origin/<base>...HEAD
   ```
   - What was changed?
   - Why was it changed?
   - Are there breaking changes?

4. **Generate the description**:

   **Title**:
   - Start with conventional commit type
   - Be specific and clear
   - Example: `feat: add user authentication with JWT`
   - If the project squashes on merge, the title becomes the permanent commit
     message -- write it to stand alone in `git blame`

   **Body formatting** -- GitHub and GitLab both render every newline in the
   body as a hard line break, so:
   - Never hard-wrap paragraphs to a column; a 72-column wrap displays as a
     narrow ragged column
   - Let paragraph lines run long; separate paragraphs with blank lines
   - Lists, headings, and code fences render as written and are fine

   **Description template** (drop sections that do not apply):
   ```markdown
   ## Summary
   Brief description of what this change does

   ## Changes
   - Change 1
   - Change 2

   ## Testing
   - [ ] Unit tests added/updated
   - [ ] Integration tests passing
   - [ ] Manual testing completed

   ## Breaking Changes
   None / List any breaking changes

   ## Screenshots (if applicable)
   [Add screenshots for UI changes]
   ```

5. **Link issues**:
   - `Closes #123` / `Fixes #456` work on both forges
   - `Relates to #789` for context without auto-close
   - If the branch or task carries an external ticket key (e.g. a Linear
     `ENG-123`), include it in the body so the tracker links the change

## Output

Show:
1. The title
2. The body
3. The exact create command for the detected forge, ready to run

Then stop. Do not run `gh pr create` or `glab mr create` yourself -- per the
outward-facing-writes policy the human runs the command or grants it
explicitly for the task.
