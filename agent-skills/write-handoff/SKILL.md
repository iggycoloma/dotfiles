---
name: write-handoff
description: |
  Compact the current session into a handoff document a fresh agent can pick up
  and continue from. TRIGGER when the user asks for a handoff, wants to
  continue work in a new session or worktree, or asks to package the current
  state for another agent. SKIP for end-of-task summaries addressed to the user
  rather than to a successor agent.
---

Write a handoff document summarizing the current conversation so a fresh agent can continue the work without re-deriving it.
Save it to the operating system's temporary directory, not the current workspace, unless the user names a destination.

If the user said what the next session will focus on, tailor the document to that focus: front-load what that session needs and compress the rest.

Include:

- **Objective**: what the overall task is and what "done" looks like.
- **State**: what has been completed, what is in progress, and what has not been started. Name the branch, worktree, or directory the work lives in.
- **Decisions**: choices already made with the user, with the reason, so the successor does not relitigate them.
- **Next steps**: the concrete actions the successor should take first, in order.
- **Suggested skills**: which skills the next agent should invoke, and for which step.
- **Gaps and risks**: anything unverified, failing, or deliberately skipped, stated plainly.

Do not duplicate content already captured in durable artifacts (specs, plans, ADRs, issues, commits, diffs).
Reference them by path, identifier, or URL instead: the successor can read the source, and a copy goes stale.

Redact any sensitive information: API keys, tokens, passwords, personally identifiable data.
Write `<REDACTED>` in its place and note where the real value lives (an environment variable, a secret store) so the successor can reach it legitimately.

Finish by telling the user the document's path and the one-line instruction to give the next agent.
