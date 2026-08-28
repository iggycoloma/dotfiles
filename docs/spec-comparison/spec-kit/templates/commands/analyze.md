# /analyze

Read-only, non-destructive analysis of the spec / plan / tasks / constitution trio for a feature folder.
Produces a findings report; does not modify files.

## Inputs
- `specs/NNN-<feature>/spec.md`
- `specs/NNN-<feature>/plan.md`
- `specs/NNN-<feature>/tasks.md`
- `.specify/memory/constitution.md`
- (Optional) `data-model.md`, `contracts/`, `research.md`, `checklists/*.md`.

## Workflow

1. **Initialize analysis context.** Load all artifacts; build a semantic model of the feature internally.
2. **Detection passes** (run all):
   - **Duplication** -- same FR-### restated under different IDs; same scenario in multiple stories.
   - **Ambiguity** -- vague phrases ("appropriately handles", "reasonable defaults"); under-specified Acceptance Scenarios.
   - **Underspecification** -- FR-### with no corresponding task; SC-### with no measurable threshold.
   - **Constitution alignment** -- plan claims PASS on Constitution Check but the implementation pattern violates an article.
   - **Coverage gaps** -- task IDs that don't trace back to any FR-### or User Story.
   - **Terminology inconsistency** -- "user" vs "actor" vs "principal" used interchangeably; Key Entity name doesn't match contract field name.
3. **Severity assignment**:
   - **CRITICAL** -- constitution violation, missing test for a P1 user story, contract that contradicts the spec.
   - **HIGH** -- coverage gap on a P1/P2 user story, ambiguity that blocks implementation.
   - **MEDIUM** -- duplication, terminology inconsistency, missing edge case.
   - **LOW** -- formatting issues, optional sections that would improve clarity.
4. **Report** -- compact Markdown findings table: `| Severity | Category | Artifact | Finding | Suggested Action |` Plus a coverage summary (% of FR-### with tests, % of User Stories with complete acceptance scenarios) and a metric summary.
5. **Offer remediation** -- list actionable fixes but do NOT apply them.
   `/analyze` is read-only.

## Output

Stdout report.
Does not write any file.
Exit code 0 if no CRITICAL findings; non-zero otherwise (so CI can gate on it).

## Hooks
- Post: `hooks.after_analyze`.

## Constraints
- STRICTLY READ-ONLY.
  No edits.
  No file creation.
- Constitution-driven: violations are CRITICAL by default.
- Cap findings at 50 (aggregate the rest into "X additional MEDIUM findings of type Y").
