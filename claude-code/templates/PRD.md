---
# Optional structured task block. When present, ralph.sh --spec-file reads
# these tasks in order, runs each task's `verify` shell command after the
# iteration, and flips `done: true` on success. Free-form prose below is
# still read by the agent for context; it is not parsed.
#
# Remove this frontmatter entirely if you want purely prose-driven runs.
spec_version: 1
project: example-project
tasks:
  - id: task-1
    description: One-sentence outcome for the first task.
    verify: "make test"
    done: false
  - id: task-2
    description: One-sentence outcome for the second task.
    verify: "make test && test -f dist/bundle.js"
    done: false
---

# Feature: [Name]

<!--
This PRD will be read by an AI agent (Claude) running autonomously in a loop.
Each iteration, it picks the NEXT incomplete task and implements it.

Write for an agent with no context: be explicit about files, commands, and
acceptance criteria. Avoid "figure out X" -- if you have to figure it out,
the agent will too, and it'll be slower and more expensive.
-->

## Context

[2-3 sentences: what this feature does, why it exists, what problem it solves.
Include just enough background that the agent can make reasonable judgment calls.]

## Success Criteria

The feature is complete when ALL of these are true:

- [ ] [Behavioral outcome 1 -- what a user can now do]
- [ ] [Behavioral outcome 2]
- [ ] All new code has tests
- [ ] `make test` (or equivalent) passes
- [ ] `make lint` (or equivalent) passes
- [ ] No files outside the agreed scope were modified

## Scope

### In scope
- [Component/area 1]
- [Component/area 2]

### Out of scope (do not touch)
- [Component/file 1 -- explain why, so agent does not re-scope]
- [Component/file 2]
- Documentation updates (handle separately)
- Dependencies beyond what's in [package.json / go.mod / etc.]

## Technical Context

### Relevant files
- `path/to/existing/file.ext` -- [what it does, how it relates]
- `path/to/another.ext` -- [what it does]

### Patterns to follow
- [e.g., "All API handlers live in `api/handlers/`, named `handle_*.go`"]
- [e.g., "Tests use pytest fixtures from `tests/conftest.py`"]
- [e.g., "Error handling follows the pattern in `src/errors.ts`"]

### Patterns to avoid
- [e.g., "Do not add new dependencies without asking"]
- [e.g., "Do not refactor unrelated code, even if tempting"]

### Existing utilities to reuse
- `function_name()` in `path/to/file` -- [what it does]
- [Any other utilities the agent might not discover]

## Tasks

<!--
Each task should be:
- Sized for roughly one iteration (one logical change + tests + commit)
- Independent where possible (so order doesn't matter much)
- Verifiable (has clear "done" criteria)

Order matters: tasks are picked top-to-bottom. Front-load prerequisites.
-->

### Task 1: [Concise verb-first title]

**Goal:** [One sentence.]

**Implementation:**
- [Specific change 1 -- file, function, what to add/modify]
- [Specific change 2]

**Done when:**
- [Verifiable outcome 1]
- [Test passes: `command to run`]

**Commit message:** `feat(scope): [conventional commit subject]`

---

### Task 2: [Concise verb-first title]

**Goal:** [One sentence.]

**Implementation:**
- [Specific change 1]
- [Specific change 2]

**Done when:**
- [Verifiable outcome 1]

**Commit message:** `feat(scope): [conventional commit subject]`

---

### Task 3: [Concise verb-first title]

[Same structure]

## Verification Steps

After all tasks are complete, run:

```bash
make test
make lint
# or whatever your project uses
```

If everything passes, write `## COMPLETE` as the last line of `progress.txt`.

## Known Risks / Gotchas

- [e.g., "The auth middleware caches tokens for 5min; tests may need to clear cache"]
- [e.g., "The migration must run before the feature flag is enabled"]
- [e.g., "This library has a breaking change between v2 and v3 -- we're on v2"]

## When Stuck

If you hit a blocker you cannot resolve:

1. Document the blocker in the Blockers section of `progress.txt`
2. Skip the blocked task
3. Work on the next unblocked task
4. Do NOT invent workarounds that silently change requirements
5. Do NOT add TODO comments and move on -- document in progress.txt instead
