---
name: review-design
description: Review an RFC, ADR, proposal, or planned architecture before implementation for problem fit, alternatives, boundaries, failure behavior, operability, migration, and reversibility. Use when the unit under review is a design rather than a diff or existing subsystem.
---

# Review a design

Evaluate whether the proposal solves the established problem with a mechanism whose costs and failure modes are understood.

## Establish the decision

1. Identify the decision being made, its owner, current state, desired outcome, and deadline or forcing function.
2. Separate requirements and fixed constraints from preferences and proposed mechanisms.
3. Confirm the evidence for the problem: affected users or systems, frequency, scale, and cost of leaving it unchanged.
4. State what is in scope, out of scope, and treated as a fixed dependency.

If the problem or success criteria cannot be stated clearly, make that the first required revision rather than reviewing implementation detail.

## Review lanes

Apply the lanes relevant to the proposal:

- Problem fit: does the design address the root problem rather than an adjacent symptom?
- Alternatives: is the status quo included, and were credible simpler mechanisms considered fairly?
- Boundaries: are ownership, APIs, data authority, and cross-team contracts explicit?
- Invariants: where are correctness rules enforced, and does that mechanism cover every writer and transition?
- Failure behavior: timeouts, partial failure, retries, idempotency, overload, recovery, and degraded modes.
- Data and compatibility: version skew, schema evolution, backfills, retention, privacy, and consistency.
- Operability: logs, metrics, traces, alerts, support diagnostics, capacity signals, and safe operator controls.
- Security: trust boundaries, authorization decisions, sensitive data, abuse paths, and dependency integrity.
- Delivery: migration order, rollout, rollback, dependencies, testing strategy, and irreversible points.
- Cost: implementation, ongoing operations, cognitive load, vendor or platform lock-in, and what the design retires.

## Evidence bar

Every finding must cite a proposal section or repository mechanism and explain the consequence. Distinguish a missing decision from a rejected alternative and an actual defect. Do not turn stylistic preference into required work.

## Output

Return one of:

- `ACCEPT`: ready to implement under the stated assumptions.
- `REVISE`: direction is viable but named changes are required.
- `NEEDS_EVIDENCE`: the decision cannot be made responsibly from current evidence.

Report required changes first, then non-blocking improvements, unresolved decisions, and one strongest alternative with its cost. Include what should remain unchanged and why.
