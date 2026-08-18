---
name: assess-release
description: Decide whether a change or release candidate is ready to ship using repository, CI, migration, rollback, observability, and operational evidence. Use for release-readiness or deployment-readiness requests; do not deploy or claim external checks passed without evidence.
---

# Assess release readiness

Answer whether the named release candidate is ready and identify the smallest missing evidence or work needed to make it ready.

## Establish the candidate

Identify the exact commit, branch, tag, artifact, diff, environment, and intended rollout scope. If the candidate is ambiguous, report that before interpreting test or deployment evidence that may belong to another revision.

## Evidence states

Classify every applicable check as:

- `VERIFIED`: direct current evidence supports it.
- `FAILED`: direct evidence shows it does not meet the requirement.
- `UNKNOWN`: applicable but evidence is missing, stale, inaccessible, or tied to another revision.
- `NOT_APPLICABLE`: explain why the lane does not apply.

Unknown is not passed. Do not infer production configuration, backups, staging results, approvals, or stakeholder readiness from repository files alone.

## Readiness lanes

Select the lanes relevant to the candidate:

- Scope: intended changes only, no unresolved blockers, durable title and release notes.
- Verification: required tests, lint, build, artifacts, signatures, and checks tied to the exact revision.
- Compatibility: clients, schemas, protocols, configuration, runtime versions, and dependency ordering.
- Migration: phase entry criteria, backfill state, version skew, irreversible points, and cleanup ownership.
- Rollout: feature flags, canary or staged exposure, stop conditions, and blast-radius controls.
- Rollback: executable procedure, data compatibility, artifact availability, and rollback verification.
- Observability: changed behavior has diagnostic signals, dashboards or queries, alert thresholds, and an accountable watcher.
- Operations: runbook, support diagnostics, capacity, external dependencies, and required human approvals.
- Security: unresolved audit findings, credential handling, authorization changes, and supply-chain evidence.

Run local checks only when they are safe, relevant, and not already represented by trustworthy current CI evidence. Never mutate staging or production as part of an assessment unless explicitly authorized.

## Decision

Return one of:

- `READY`: every required lane is verified or not applicable.
- `READY_WITH_CONDITIONS`: remaining conditions are explicit, owned, and can be verified before exposure without changing the candidate.
- `NOT_READY`: a failed requirement, unresolved blocker, unsafe ordering, or missing evidence prevents responsible release.

## Output

Lead with the decision and exact candidate. Provide a compact evidence table, blockers and conditions, rollout and rollback summary, checks run, evidence not accessed, and the next decision point. Do not deploy, publish, notify stakeholders, or change issue state unless separately authorized.
