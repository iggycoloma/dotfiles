---
name: create-pr
description: |
  Draft a pull request (GitHub) or merge request (GitLab) with proper
  formatting, or revise an existing one's title and body after the branch
  changes. Detects the forge from the git remote, composes the title and
  body, and hands them over -- creation and edits run only with explicit
  approval.
  PRECEDENCE: a repo-provided skill covering PR or MR creation for the
  current repository outranks this skill -- invoke that one, and use this
  only for what it does not cover.
---

You are drafting a pull request or merge request, or revising the title
and body of one that already exists for the branch.

Before composing, check for repo-specific conventions and defer to them on
any point they specify: a PR/MR template (`.github/PULL_REQUEST_TEMPLATE.md`,
`.github/PULL_REQUEST_TEMPLATE/`, `.gitlab/merge_request_templates/`),
contribution rules in `CONTRIBUTING.md`, and the project's agent
instructions (CLAUDE.md / AGENTS.md). A repo template overrides the body
shape below; this skill fills only the gaps the repo leaves.

## Process

1. **Detect the forge**:
   ```bash
   git remote get-url origin
   ```
   - GitHub host -> `gh`, "pull request", `gh pr create`
   - GitLab host (gitlab.com or self-hosted) -> `glab`, "merge request", `glab mr create`
   - Anything else -> compose the title and body anyway and say no forge CLI is configured for that host

2. **Detect an existing PR or MR** for the current branch:
   ```bash
   gh pr view --json number,title,body
   glab mr view
   ```
   If one exists, this run revises it: regenerate the title and body from
   the full current diff so the description stays true of the final state
   (per `prompts/forge.md` -- never append a changelog of revisions), and
   emit the edit command in the Output step instead of create.

3. **Verify state**. Use the base named by the user; otherwise determine the
   default branch with `git symbolic-ref refs/remotes/origin/HEAD` rather
   than assuming `main`. Then:
   ```bash
   git status
   git log origin/<base>..HEAD --oneline
   ```
   - Changes are committed
   - On a feature branch
   - Up to date with the base branch

4. **Analyze changes**:
   ```bash
   git diff origin/<base>...HEAD
   ```
   - What was changed?
   - Why was it changed?
   - Are there breaking changes?

5. **Generate the description**:

   **Title**:
   - Start with conventional commit type
   - Be specific and clear
   - Example: `feat: add user authentication with JWT`
   - If the project squashes on merge, the title becomes the permanent commit
     message -- write it to stand alone in `git blame`

   **Body formatting, content, and shape**: read the deployed `prompts/forge.md` for the active agent,
   the canonical statement of both. It is NOT loaded by default, so read the
   file rather than working from memory -- a second template here would drift
   from it. In short: no hard-wrapping (every newline renders as a break),
   final form rather than lifecycle, and Summary / What changed / Safety and
   compatibility / Testing / Known follow-up.

   Add a Screenshots section for UI changes; it is outside that shape because
   it applies to a minority of changes.

6. **Link issues**:
   - `Closes #123` / `Fixes #456` work on both forges
   - `Relates to #789` for context without auto-close
   - If the branch or task carries an external ticket key (e.g. a Linear
     `ENG-123`), include it in the body so the tracker links the change

## Output

Show:
1. The title
2. The body
3. The exact command for the detected forge, ready to run: `gh pr create`
   / `glab mr create`, or for an existing PR/MR `gh pr edit --body-file`
   / `glab mr update --description`

Then stop. Do not run the create or edit command yourself -- per the
outward-facing-writes policy the human runs the command or grants it
explicitly for the task.
