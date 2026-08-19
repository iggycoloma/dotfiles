---
name: implement-tdd
description: |
  Test-driven implementation: red-green loop with tests at pre-agreed public
  seams. TRIGGER when the user wants a feature or fix built test-first,
  mentions TDD or red-green-refactor, or asks for integration tests around new
  behavior. SKIP when diagnosing an existing failure (use debug) or when the
  user explicitly wants code without tests.
---

# Test-driven implementation

TDD is the red to green loop.
This skill is the reference that makes the loop produce tests worth keeping: what a good test is, where tests go, the anti-patterns, and the rules of the loop.
Every section applies on every cycle.

Before the first cycle, read whatever domain documentation the project keeps (glossary, ADRs, architecture notes) so test names and interface vocabulary match the project's language.

## What a good test is

Tests verify behavior through public interfaces, not implementation details.
Code can change entirely; tests should not.
A good test reads like a specification: "user can checkout with valid cart" says exactly what capability exists, and it survives refactors because it does not care about internal structure.

See [tests.md](tests.md) for worked examples and [mocking.md](mocking.md) for when and how to mock.

## Seams: where tests go

A **seam** is the public boundary you test at: the interface where you observe behavior without reaching inside.
Tests live at seams, never against internals.

**Test only at pre-agreed seams.**
Before writing any test, write down the seams under test and confirm them with the user.
You cannot test everything, so agreeing the seams up front is how testing effort lands on critical paths and complex logic instead of every edge case.
Prefer existing seams to new ones, and the highest seam that still exercises the behavior directly.

Ask: "What is the public interface, and which seams should we test?"

## Anti-patterns

- **Implementation-coupled**: mocks internal collaborators, tests private methods, or verifies through a side channel (querying the database instead of using the interface). The tell: the test breaks on refactor while behavior is unchanged.
- **Tautological**: the assertion recomputes the expected value the way the code does, so it passes by construction and can never disagree with the code. Expected values come from an independent source of truth: a known-good literal, a worked example, the spec.
- **Horizontal slicing**: writing all tests first, then all implementation. Bulk tests verify imagined behavior and commit to test structure before the implementation is understood. Work in **vertical slices**: one test, one implementation, repeat, each test a tracer bullet that responds to what the last cycle taught.

## Rules of the loop

- **Red before green.** Write the failing test first and watch it fail, then write only enough code to pass it. No speculative features.
- **One slice at a time.** One seam, one test, one minimal implementation per cycle.
- **Refactoring is a separate pass.** It belongs to review (see the review-pr skill), not inside the red-green cycle.
