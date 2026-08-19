---
name: specify-feature
description: Produce an implementation-ready feature specification with users, observable acceptance criteria, constraints, edge cases, rollout, and explicit scope. Use when a user asks to specify or plan a feature before architecture or implementation.
---

# Feature specification

Turn the requested feature into a decision-ready specification. Do not invent product targets, compliance obligations, scale requirements, APIs, or storage designs.

## Discover context

1. Identify the user, problem, desired outcome, and why the work matters now.
2. Read relevant repository behavior, terminology, constraints, and existing adjacent features.
3. Separate known facts, reasonable inferences, and unresolved product decisions.
4. Ask only questions whose answers materially change scope or acceptance. If work can continue safely, record the assumption and proceed. When the open decisions are numerous or interdependent, offer to run grill-plan first and feed its settled decisions into this spec.

## Required sections

### Overview

State the problem, target users, outcome, and concise proposed capability.

### User stories

Include only distinct user goals. Avoid restating implementation tasks as stories.

### Acceptance criteria

Write observable, testable criteria. Use Given/When/Then when state or sequencing matters. Cover the primary flow, permissions, validation, failure behavior, and recovery where applicable.

### Constraints and compatibility

Record relevant platform, repository, performance, security, accessibility, migration, and operational constraints found in evidence. Mark unknown targets as decisions; never fill them with stock numbers.

### Edge cases

Cover boundary inputs, empty and duplicate state, concurrency or retry behavior, partial failure, backward compatibility, and cleanup only where the feature makes them relevant.

### Rollout and observability

Describe migration order, feature gating, rollback, telemetry, and support diagnostics when the change has operational risk. Otherwise state that no special rollout is required and why.

### Testing decisions

Name the seams the feature will be verified at: the public interfaces where acceptance criteria become tests. Prefer existing seams to new ones, and the highest seam that still exercises the behavior directly; propose new seams only where no existing one reaches the behavior. Note prior art -- similar tests already in the codebase. Confirm the seams with the user before the spec is called ready.

### Dependencies and open decisions

Name prerequisite work, external contracts, ownership boundaries, and decisions that block architecture or implementation.

### Out of scope

Name plausible adjacent work that this feature deliberately excludes.

## Keep design at the right level

Specify required behavior and constraints. Include an API or data model only when it is already fixed by the request or repository; otherwise leave mechanism choices for architecture. Do not turn the spec into an implementation plan.

## Output

Report the specification in chat unless the user or repository names a destination. When writing a file, use the repository's planning convention; do not create a tool-specific `.claude` or `.codex` artifact path. Close with unresolved decisions and whether the spec is ready for architecture.
