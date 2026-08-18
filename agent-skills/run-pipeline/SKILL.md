---
name: run-pipeline
description: Run the staged feature-development workflow from specification through design review, implementation, and release assessment, pausing for user approval between stages. Use when the user explicitly asks for the full pipeline.
---

You are orchestrating the 4-stage feature development pipeline.

## Feature

Use the feature name or description supplied by the user. If none was supplied, ask what feature to build.

## Pipeline Stages

This pipeline runs four roles in sequence. Use a configured specialized agent
for a role when the active tool provides one; otherwise perform that stage in
the current session. Each stage produces an artifact that feeds the next.

### Stage 1: PM specification (`specify-feature`)
**Goal**: Gather requirements, write a specification document.
**Output**: A specification in the repository's planning location with user stories, acceptance criteria, constraints, edge cases, and scope.
**Role**: PM/specification agent when configured.

### Stage 2: Architecture review (`review-design`)
**Goal**: Validate the spec, produce an Architecture Decision Record (ADR).
**Output**: ADR document with component breakdown, API contracts, data models, and risk assessment.
**Role**: Architect agent when configured; give it the approved specification.
**Gate**: Status must be `READY_FOR_BUILD` before proceeding.

### Stage 3: Implementation and testing
**Goal**: Build the feature per the architectural design, with comprehensive tests.
**Output**: Working code with tests passing.
**Role**: Implementer/tester agent when configured; give it the approved specification and ADR.

### Stage 4: QA and release assessment (`assess-release`)
**Goal**: Validate the implementation against the spec, run final checks.
**Output**: QA report with pass/fail status.
**Role**: QA agent when configured; give it the specification, ADR, implementation diff, and test results.
**Gate**: The implementation must satisfy the specification and the release decision must be `READY` or an explicitly accepted `READY_WITH_CONDITIONS`.

## How to Run

1. Start Stage 1 now with the feature description.
2. After Stage 1 completes, review the spec with the user before proceeding
3. Run each subsequent stage, pausing between stages for user review
4. If any stage identifies blockers, resolve them before continuing

## Between Stages

- Show the user what the current stage produced
- Ask if they want to proceed, revise, or stop
- Each stage builds on the previous stage's artifacts

## Output

After completing Stage 1, summarize:
- What the pipeline will produce
- Expected artifacts at each stage
- That the user will be consulted between stages
