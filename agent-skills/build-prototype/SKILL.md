---
name: build-prototype
description: |
  Build a throwaway prototype that answers one design question: whether a
  state model or logic feels right, or what a UI should look like. TRIGGER
  when the user wants to sanity-check a design idea with something runnable
  before committing to it. SKIP when the question is which technology to
  adopt (use evaluate-technology) or when production code is being requested.
disable-model-invocation: true
---

# Build a prototype

A prototype is **throwaway code that answers a question**.
The question decides the shape:

- "Does this logic or state model feel right?" builds a minimal runnable harness (often a single HTML file or script) that pushes the model through the cases that are hard to reason about on paper, with free-play controls plus a few guided walkthroughs a non-developer can drive.
- "What should this look like?" builds several radically different UI variations on one route, switchable in place, so the user reacts to concrete alternatives instead of one anchor.

Getting the branch wrong wastes the whole prototype.
If the question is ambiguous and the user is not reachable, default to whichever branch matches the surrounding code (backend module: logic; page or component: UI) and state the assumption at the top of the prototype.

## Rules

1. **Throwaway from day one, and marked as such.** Put it near the module or page it prototypes so context is obvious, named so a casual reader sees it is not production. Follow the project's existing routing or scripting conventions rather than inventing structure.
2. **Trivial to run.** One command in the project's task runner, or a single file the user opens. No thinking required to start it.
3. **No persistence by default.** State lives in memory; persistence is usually the thing being checked, not a dependency. If the question involves a database, use a scratch target with a clear "prototype, wipe me" name.
4. **Skip the polish.** No tests, no error handling beyond runnability, no abstractions. The point is to learn fast.
5. **Surface the state.** After every action, print or render the full relevant state so the user sees what changed.
6. **Capture it when done.** Fold the validated decision into the real code or spec. Commit the prototype itself to a throwaway branch off the mainline and leave a pointer to it from the relevant issue or ADR, along with the verdict and the question it settled. The mainline keeps only the validated decision.
