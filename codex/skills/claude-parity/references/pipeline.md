# Feature Pipeline

Run this staged workflow when the user asks for pipeline-style delivery.

## Stage 1: PM Spec

Output: specification document with status `READY_FOR_ARCH`.

Checklist:

1. Clarify goals, target users, and business value.
2. Write user stories and acceptance criteria.
3. Capture functional/non-functional requirements.
4. List edge cases, dependencies, and out-of-scope items.

## Stage 2: Architecture Review

Output: ADR-level plan with status `READY_FOR_BUILD`.

Checklist:

1. Validate design against existing architecture.
2. Define key technical decisions and alternatives.
3. Record security/performance/scalability implications.
4. Specify component boundaries and integration contracts.

## Stage 3: Implementation and Testing

Output: working code + tests with status `READY_FOR_QA`.

Checklist:

1. Implement according to spec + ADR.
2. Add unit/integration tests for new behavior.
3. Keep changes scoped and maintainable.
4. Run relevant verification commands and record results.

## Stage 4: QA Review

Output: validation report with status `DONE` or `NEEDS_WORK`.

Checklist:

1. Verify acceptance criteria and edge cases.
2. Confirm tests pass and coverage is reasonable.
3. Check security and release-readiness concerns.
4. Produce explicit go/no-go verdict.

## Gate Rules

- Pause after each stage and show artifact summary.
- Ask whether to proceed, revise, or stop.
- Do not skip failed gates; resolve blockers first.
