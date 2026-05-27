# /tasks

Generate a phased, dependency-aware task list from `plan.md`.

## Inputs
- `specs/NNN-<feature>/plan.md` -- the plan being decomposed.
- `specs/NNN-<feature>/spec.md` -- to extract User Story groupings.
- Optional: `data-model.md`, `contracts/`, `research.md`, `quickstart.md`.

## Workflow

1. **Load all relevant artifacts.** Plan + spec are required; design docs are optional.
2. **Extract user stories** from the spec, ordered by priority (P1, P2, ...).
3. **Build task list** organized into phases:
   - **Phase 1: Setup** -- shared infrastructure: project scaffolding, build tools, test framework setup.
   - **Phase 2: Foundational** -- blocking prerequisites: data models, API contracts, persistence layer.
   - **Phase 3+: User Story N** (one phase per priority tier).
     Within each phase: `### Tests for User Story N` followed by `### Implementation for User Story N`.
     TDD enforced.
   - **Phase Final: Polish** -- logging, optimization, error handling, documentation.
4. **ID and tag** every task:
   - ID format: `T001`, `T002`, ..., `T0XX` (zero-padded sequential).
   - `[P]` marker if the task is safe to run in parallel with sibling `[P]` tasks (different files, no shared state).
   - `[USN]` tag (story number) for tasks under Phase 3+.
   - `MVP` and `CRITICAL` markers for emphasis.
5. **Build dependency notes**:
   - `## Dependencies & Execution Order` -- which phases block which.
   - `## Parallel Example: User Story 1` -- a worked example of which `[P]` tasks can run together.
6. **Implementation Strategy** -- MVP scope, incremental delivery rules, team coordination notes.

## Output

Writes `specs/NNN-<feature>/tasks.md` populated from `.specify/templates/tasks-template.md`.

## Hooks
- Pre: `hooks.before_tasks`.
- Post: `hooks.after_tasks`.

## Constraints
- TDD is non-negotiable.
  `### Tests for User Story N` always precedes `### Implementation for User Story N`.
- A reasonable task is 30 minutes to 4 hours.
  Bigger -> break it down.
- `[P]` is a CLAIM, not a hope.
  Two tasks marked `[P]` must touch disjoint files and no shared in-memory state.
- Phase Final never starts until all User Story phases are complete.
