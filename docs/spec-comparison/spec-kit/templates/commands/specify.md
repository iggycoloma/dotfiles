# /specify

Generate a feature specification from a user description.

## Inputs
- `$ARGUMENTS` -- user's free-text feature description.
- `.specify/memory/constitution.md` -- project principles (read-only, used for
  awareness; full validation happens in `/plan`'s Constitution Check).
- Existing `specs/NNN-*` folders -- for next-numeric-prefix selection.

## Workflow

1. **Parse user input.** Extract concepts: actors, actions, data, constraints,
   non-goals.
2. **Allocate feature folder.** Create `specs/NNN-<kebab-feature-name>/` where
   `NNN` is the next zero-padded sequential prefix.
3. **Fill scenarios.** For each priority tier (P1, P2, P3...), write a User
   Story with: Why this priority / Independent Test / Acceptance Scenarios in
   GIVEN / WHEN / THEN form. P1 should be the smallest meaningful slice.
4. **Generate functional requirements.** Numbered `FR-001`, `FR-002`, ...
   Each requirement is testable from outside the system.
5. **Define success criteria.** Numbered `SC-001`, ..., technology-agnostic
   measurable outcomes.
6. **Identify Key Entities** (only if the feature involves data models).
7. **Capture edge cases** in their own `### Edge Cases` subsection under
   `## User Scenarios & Testing`.
8. **List assumptions** about users, scope, dependencies.
9. **Validate**: at most 3 `[NEEDS CLARIFICATION]` markers in the produced
   spec. If more, you are guessing too much -- ask the user instead.

## Output

Writes `specs/NNN-<feature>/spec.md` populated from
`.specify/templates/spec-template.md`.

## Hooks
- Pre: `.specify/extensions.yml -> hooks.before_specify` (if defined).
- Post: `.specify/extensions.yml -> hooks.after_specify` (if defined).

## Constraints
- DO NOT write `plan.md` or `tasks.md` here -- that's `/plan` and `/tasks`'
  job. Stay in the spec layer.
- DO NOT mention specific frameworks, libraries, or architectures unless the
  user asked. The spec is about *what*, not *how*.
- If the user's description is too vague to write meaningful Acceptance
  Scenarios, ask clarifying questions before writing the file. Better to ask
  than to fabricate.
