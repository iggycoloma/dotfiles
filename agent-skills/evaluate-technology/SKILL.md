---
name: evaluate-technology
description: Evaluate adopting, replacing, or building a technology -- library, service, platform, or vendor -- against the problem, total lifetime cost, and predefined exit criteria. Use for build-vs-buy, adopt-or-hold, and replace-X-with-Y questions; use plan-migration once the decision is made.
---

# Evaluate a technology

Answer whether a technology earns adoption, with a recommendation that names the evidence that would reverse it.

## Establish the problem first

1. State the problem and its forcing function before naming any candidate. An evaluation that starts from the technology inherits its framing; one that starts from the problem can conclude "do nothing", which is a real answer.
2. Include the status quo and a "do less" option (solve the painful subset with existing tools) as candidates on equal footing.
3. Fix the constraints with sources: team skills and size, operational capacity, compliance obligations, data gravity, and what the organization already runs -- a second queue or second cloud is a cost even when the new one is better.

## Define exit criteria before evaluating

Write down, before any spike or deep read, what evidence would reject each candidate: a latency floor, an unacceptable operational surface, a license change, a missing capability that cannot be worked around.
Criteria written after contact with the technology drift toward justifying the time already spent.

## Price the full lifetime

Evaluate every candidate on the same attributes:

- Adoption: integration work, migration of existing data or callers, team learning curve.
- Operation: who runs it, on-call surface, upgrade cadence, failure modes and their blast radius.
- Exit: what leaving costs in two years -- data egress, API coupling, retraining. Weight lock-in by exit cost, not by vendor reputation.
- Health, for external candidates: release cadence, issue triage responsiveness, maintainer depth, license and its trajectory, security response history. Popularity is a proxy that expires; measure the maintenance signals directly.
- For build: the honest internal equivalents of all of the above, including the roadmap cost of owning it forever. Build competes on the same sheet, not on pride.

## Spike only the riskiest assumption

If the decision needs evidence a document cannot provide, design the smallest timeboxed spike that tests the single assumption most likely to reject the candidate -- realistic data volume, the awkward integration, the failure mode -- not a happy-path demo.
State the spike's pass/fail condition before running it.

## Output

Recommend one of `adopt`, `trial` (with the spike design and its pass/fail condition), `hold` (with what would reopen the question), or `build` -- plus the strongest surviving argument against the recommendation.
State the decision's expiry condition: the change in scale, team, pricing, or upstream health that should trigger re-evaluation.
Record an accepted decision with draft-adr; this skill produces the evidence, that one produces the durable artifact.
