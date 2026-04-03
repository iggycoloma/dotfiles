---
description: Start feature development pipeline (PM -> Architect -> Build -> QA)
argument-hint: <feature-name or description>
allowed-tools: Read, Write, Grep, Glob
---

You are orchestrating the 4-stage feature development pipeline.

## Feature

Use `$ARGUMENTS` as the feature name or description. If no arguments, ask the user what feature to build.

## Pipeline Stages

This pipeline uses 4 specialized agents in sequence. Each stage produces an artifact that feeds the next.

### Stage 1: PM Spec (pm-spec agent)
**Goal**: Gather requirements, write a specification document.
**Output**: `.claude/specs/<feature-name>.md` with user stories, acceptance criteria, and scope.
**Trigger**: Dispatch `Agent(subagent_type="pm-spec")` with the feature description.

### Stage 2: Architecture Review (architect-review agent)
**Goal**: Validate the spec, produce an Architecture Decision Record (ADR).
**Output**: ADR document with component breakdown, API contracts, data models, and risk assessment.
**Trigger**: Dispatch `Agent(subagent_type="architect-review")` with the spec from Stage 1.
**Gate**: Status must be `READY_FOR_BUILD` before proceeding.

### Stage 3: Implementation & Testing (implementer-tester agent)
**Goal**: Build the feature per the architectural design, with comprehensive tests.
**Output**: Working code with tests passing.
**Trigger**: Dispatch `Agent(subagent_type="implementer-tester")` with the ADR and spec.

### Stage 4: QA Review (qa-reviewer agent)
**Goal**: Validate the implementation against the spec, run final checks.
**Output**: QA report with pass/fail status.
**Trigger**: Dispatch `Agent(subagent_type="qa-reviewer")` with the spec, ADR, and implementation.
**Gate**: Status must be `APPROVED_FOR_RELEASE` to complete the pipeline.

## How to Run

1. Start Stage 1 now -- dispatch the pm-spec agent with the feature description
2. After Stage 1 completes, review the spec with the user before proceeding
3. Run each subsequent stage, pausing between stages for user review
4. If any stage identifies blockers, resolve them before continuing

## Between Stages

- Show the user what the current stage produced
- Ask if they want to proceed, revise, or stop
- Each stage builds on the previous stage's artifacts

## Output

After dispatching Stage 1, summarize:
- What the pipeline will produce
- Expected artifacts at each stage
- That the user will be consulted between stages
