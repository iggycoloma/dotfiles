---
name: plan-migration
description: Plan a safe schema, API, protocol, dependency, storage, queue, or cross-service migration with compatibility sequencing, validation, rollback, and cleanup. Use when current and target states must coexist across deployments or data transitions.
---

# Plan a migration

Produce an executable path from the current state to the target state without assuming an atomic deployment.

## Map the states and participants

1. Describe the current state, target state, and reason for migrating.
2. Enumerate every reader, writer, job, script, migration, external client, and repository participating in the contract.
3. Record deployment independence, supported version skew, data volume, availability requirements, and ownership.
4. Identify invariants that must hold throughout the transition, not only after it.

## Build the sequence

Prefer an expand, migrate, contract shape when compatibility is required:

1. Expand: introduce backward-compatible schema, API, protocol, or runtime capability.
2. Observe: prove old and new versions coexist and make transition progress visible.
3. Migrate: backfill or move traffic in bounded, resumable, idempotent units.
4. Verify: reconcile counts, checksums, invariants, reads, and error rates using independent evidence.
5. Cut over: change the authority or default only after entry criteria pass.
6. Contract: remove compatibility paths after rollback and version-skew windows close.

For each phase name the owning change, prerequisites, entry and exit criteria, monitoring, rollback action, and whether rollback preserves data.

## Failure and recovery

Address partial deployment, interrupted backfills, duplicate processing, dual-write divergence, retry amplification, old clients, rollback after new writes, and operator error where relevant. Identify the point of no return explicitly; do not claim rollback remains available after incompatible data or contracts are in use.

## Delivery artifacts

Include:

- Ordered work packages and cross-repository dependencies.
- Compatibility matrix for old and new readers and writers.
- Backfill or traffic-shift batching, rate limits, pause/resume, and progress state.
- Validation queries or checks that do not rely solely on the new path.
- Rollout and rollback commands or runbook steps when known.
- Cleanup criteria, owner, and deadline so temporary paths do not become permanent.

## Output

Lead with the migration strategy and highest-risk transition. Provide the phase table, invariants, compatibility matrix, verification plan, rollback boundaries, operational controls, and open decisions. Separate facts from assumptions and do not implement until the user selects or approves the plan.
