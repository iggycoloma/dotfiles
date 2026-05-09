# /plan

Generate an implementation plan for an existing spec.

## Inputs
- `specs/NNN-<feature>/spec.md` -- the spec being planned.
- `.specify/memory/constitution.md` -- principles to validate against.
- Existing repo state -- to populate Technical Context honestly.

## Workflow

### Phase 0: Research
- Identify unknowns surfaced by the spec or by the chosen tech context.
- For each unknown, write to `specs/NNN-<feature>/research.md`: question,
  options considered, decision, rationale.
- Resolve any `[NEEDS CLARIFICATION]` markers from the spec by either
  research or escalation back to `/clarify`.

### Phase 1: Design
- Generate `data-model.md` if the feature has a non-trivial data model.
- Generate `contracts/<name>.{md,json,yaml}` if the feature exposes interfaces
  (HTTP, CLI, hook, file format).
- Generate `quickstart.md` if a user-facing setup snippet would help.
- Choose a project structure pattern: Single Project / Web Application /
  Mobile + API. Document the choice in `## Structure Decision`.

### Phase 2: Plan write
Populate `specs/NNN-<feature>/plan.md` with:
- **Branch / Date / Spec** front-matter.
- **Summary** -- primary requirement and chosen technical approach.
- **Technical Context** -- Language/Version, Primary Dependencies, Storage,
  Testing, Target Platform, Project Type, Performance Goals, Constraints,
  Scale/Scope.
- **Constitution Check** -- explicit pass/fail per article. PASS, FAIL with
  justification in Complexity Tracking, or N/A.
- **Project Structure** -- Documentation hierarchy + Source Code layout +
  Structure Decision.
- **Complexity Tracking** -- table of `Violation | Why Needed | Simpler
  Alternative Rejected Because` for any deviation from the constitution or
  from a constitution-recommended pattern.

## Output

Writes (or updates):
- `specs/NNN-<feature>/plan.md` (always).
- `specs/NNN-<feature>/research.md` (if Phase 0 surfaced research items).
- `specs/NNN-<feature>/data-model.md` (if applicable).
- `specs/NNN-<feature>/contracts/` (if applicable).
- `specs/NNN-<feature>/quickstart.md` (if applicable).

## Hooks
- Pre: `hooks.before_plan`.
- Post: `hooks.after_plan`.

## Constraints
- Constitution Check is a HARD gate. Failures with un-justified violations
  block the transition to `/tasks`.
- Plan describes *how*, not *what*. Anything in the spec that says "what"
  should not be re-stated in the plan; reference the spec instead.
- Project structure -- pick one of the three patterns. Deviations require
  Complexity Tracking entry.
