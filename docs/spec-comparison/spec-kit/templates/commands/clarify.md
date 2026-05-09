# /clarify

Resolve ambiguities in `spec.md` by asking the user up to 5 high-impact
questions, one at a time, integrating each answer back into the spec.

## Inputs
- `specs/NNN-<feature>/spec.md` -- the spec to clarify.
- The 11-category ambiguity taxonomy (scope boundaries, success metrics, edge
  cases, data model gaps, contract ambiguities, non-functional gaps,
  terminology, dependencies, assumptions, acceptance phrasing,
  out-of-scope drift).

## Workflow

1. **Scan the spec** against the 11-category taxonomy. Score each potential
   ambiguity by impact-on-implementation. Discard low-impact items.
2. **Pick top N** (max 5) and present them as a numbered list to the user --
   but ONLY ask the first one.
3. **Wait for answer.** Integrate it back into the spec immediately
   (modifying the relevant FR-### / SC-### / Acceptance Scenario / Edge Case).
4. **Loop**: ask the next question. Repeat. Up to 5 total.
5. **Honor early termination.** "done", "stop", "proceed" -- accept and stop
   asking even if questions remain.
6. **Validate**: re-scan after the loop. If unresolved high-impact ambiguities
   remain, mark them with `[NEEDS CLARIFICATION]` in the spec rather than
   guessing.
7. **Report**: brief summary of what was clarified and what was deferred.

## Output

Modifies `specs/NNN-<feature>/spec.md` in place. No new files.

## Constraints
- Ask one question at a time. Multi-question dumps overwhelm and produce
  lower-quality answers.
- Each question must be specific enough that the answer changes the spec.
  ("Should we support dark mode?" is good. "Are there any other things to
  consider?" is bad.)
- Strictly capped at 5 questions per invocation.
