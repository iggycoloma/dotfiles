---
name: resolve-conflicts
description: |
  Resolve an in-progress git merge or rebase conflict hunk by hunk, from the
  intent behind each side. TRIGGER when a merge, rebase, or cherry-pick has
  stopped on conflicts, or the user asks to resolve conflict markers. SKIP
  when there is no conflict in progress and the user wants a merge strategy
  planned instead.
---

1. **See the current state** of the merge or rebase: which operation is in progress, which files conflict, and what the operation was trying to achieve.

2. **Find the primary sources** for each conflict.
   Understand why each side changed: read the commit messages, the PRs or MRs, and the originating issues or tickets.
   Resolve from intent, never from surface text.

3. **Resolve each hunk.**
   Preserve both intents where possible.
   Where they are incompatible, pick the side matching the merge's stated goal and note the trade-off to the user.
   Do not invent new behaviour.
   Always resolve; never abort the operation.

4. **Run the project's automated checks**: typically typecheck, then tests, then format.
   Fix anything the merge broke.

5. **Finish the operation.**
   Stage everything and commit.
   If rebasing, continue until all commits are replayed.
   Report which hunks required an intent judgement and which trade-offs were made.
