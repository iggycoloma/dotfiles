# /implement

Execute the tasks in `tasks.md` against the codebase, marking each task `[X]`
as it completes. Halts on test failures and on incomplete checklists.

## Inputs
- `specs/NNN-<feature>/tasks.md` -- the source of truth for what to do.
- `specs/NNN-<feature>/plan.md` -- for Technical Context and Project Structure.
- Optional: `data-model.md`, `contracts/`, `research.md`,
  `checklists/*.md`.

## Workflow

1. **Prerequisite check.** Required tools, language runtimes, and test
   frameworks installed? If not, halt with explicit message.
2. **Checklist validation.** If `checklists/` contains any `- [ ]` items,
   halt and ask the user to complete them or explicitly skip.
3. **Context loading.** Read tasks.md + plan.md (required); read optional
   design docs as referenced.
4. **Project setup.** Verify or create `.gitignore`, `.dockerignore`,
   `.eslintignore` etc. as plan dictates.
5. **Task parsing.** Build the dependency graph from phases, `[P]` markers,
   and `[USN]` tags.
6. **Phase-by-phase execution.**
   - Sequential phases: Setup -> Foundational -> US1 -> US2 -> ... -> Polish.
   - Within a phase, run `[P]` tasks in parallel and non-`[P]` tasks
     sequentially in declared order.
   - Within a User Story phase, `### Tests` always before `### Implementation`.
7. **Implementation rules**:
   - Tests fail first (red), then implementation (green), then optional
     refactor.
   - Each task gets a focused diff; no opportunistic refactoring of unrelated
     code.
   - Constitution articles still apply -- security checks, style, test
     coverage.
8. **Progress tracking.** Mark `- [X]` in `tasks.md` after each task. Halt on
   any test failure -- do not continue past a red test.
9. **Validation.** After Phase Final, confirm all tasks are `[X]` and the
   feature satisfies every Acceptance Scenario in spec.md.
10. **Post-hooks.** `hooks.after_implement`.

## Output

- Code changes in the repo.
- `tasks.md` updated with `[X]` markers.
- (No new files created by this command beyond what tasks themselves create.)

## Constraints
- TDD non-negotiable: tests before code, every time.
- Halt on red. Do not "fix tests later" -- fix or escalate immediately.
- Stay within scope: do not implement tasks not in tasks.md, do not refactor
  unrelated code, do not chase yak-shave suggestions from the LSP.
- Honor the Constitution Check from plan.md. If the implementation drifts
  toward a violation, stop and surface to the user.
