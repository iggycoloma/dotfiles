---
name: draft-tickets
description: |
  Break a plan, spec, or the current conversation into tracer-bullet tickets
  with explicit blocking edges, ready to publish to the project's issue
  tracker. TRIGGER when the user wants a plan decomposed into tickets, issues,
  or tasks, or asks to split a spec into agent-sized work items. SKIP when the
  work fits one session with no decomposition needed, or when the user wants
  the spec itself written first (use specify-feature).
---

# Draft tickets

Break a plan, spec, or conversation into **tickets**: tracer-bullet vertical slices, each declaring the tickets that **block** it.

Detect the tracker the way fix-issue does: a GitHub or GitLab remote means gh or glab; a configured tracker integration (for example Linear) means that tracker; otherwise fall back to local ticket files.

## Process

### 1. Gather context

Work from what is already in the conversation.
If the user passes a reference (a spec path, an issue number or URL), fetch it and read its full body and comments.

### 2. Explore the codebase

If you have not already explored the relevant code, do so.
Ticket titles and descriptions should use the project's own vocabulary, and respect ADRs in the area being touched.
Look for opportunities to prefactor: make the change easy, then make the easy change.
Prefactoring gets its own ticket, first.

### 3. Draft vertical slices

Break the work into tracer-bullet tickets:

- Each slice cuts a narrow but complete path through every layer (schema, API, UI, tests): vertical, not a horizontal slice of one layer.
- A completed slice is demoable or verifiable on its own.
- Each slice is sized to fit a single fresh agent session.

Give each ticket its **blocking edges**: the tickets that must complete before it can start.
A ticket with no blockers can start immediately.

### 4. Review with the user

Present the breakdown as a numbered list.
For each ticket show the title, what it delivers end to end, and what blocks it.
Ask whether the granularity feels right, whether the blocking edges are genuine gates, and whether any tickets should merge or split.
Iterate until the user approves.

### 5. Publish

Publish the approved tickets in dependency order (blockers first) so blocking edges can reference real identifiers.
Use the tracker's native blocking or sub-issue relationship where it has one; otherwise list blockers in the ticket body.
With no tracker, write one file per ticket under a scratch directory (for example `.scratch/<feature-slug>/issues/<NN>-<slug>.md`), numbered in dependency order.
Do not close or modify any parent issue.

Ticket body template:

```markdown
## What to build

The end-to-end behaviour this ticket makes work, from the user's perspective,
not a layer-by-layer implementation list.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Blocked by

A reference to each blocking ticket, or "None (can start immediately)".
```

Avoid specific file paths or code snippets in ticket bodies: they go stale fast.
Exception: a snippet that encodes a decision more precisely than prose (state machine, schema, type shape) may be inlined, trimmed to the decision-rich parts.

Work the **frontier**: any ticket whose blockers are all done can be picked up, in parallel where sessions allow.
