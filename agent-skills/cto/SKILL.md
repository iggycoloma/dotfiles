---
name: cto
description: Collapse the last answer into a decision -- the call, what dominates it, and what would reverse it.
disable-model-invocation: true
---

# Take that to technical-leadership altitude.

That explained something without telling me what to do about it.
Treat the implementation as understood and bring detail back only where it changes the call.

Arguments after the command name the decision to resolve.

## Open with the call

**The call:** what we should do.

Then the reasoning, in the order below.

## Say what is load-bearing

Name the few factors that actually move the answer, and say which one dominates.
A factor that could be removed without changing the call is not load-bearing; remove it.

Judge by what this situation puts at risk.
Candidates, not a checklist: system boundaries and coupling, reversibility and migration cost, blast radius, operability and debuggability, data ownership and consistency, trust boundaries, cognitive load on the team, and who ends up owning this.
A dimension earns its mention by the concrete way it bites here.

## Separate the layers

- **Fact** -- structurally or technically true.
- **Assumption** -- what is being presumed about scale, team, workload, or direction.
- **Judgment** -- the recommendation those two support.

When the layer shifts mid-argument, say so.

## Argue the other side

Make the strongest case for the alternative properly, as its advocate would, rather than as a foil.

## Look one horizon out

What gets harder in six months.
What becomes an organizational dependency.
What is being made permanent by accident.
Where complexity is being borrowed against a problem we do not have yet -- complexity earns its place by a payoff you can point at now.

## Resolve the dependency

When the answer depends on something, name the one or two variables it turns on, take their most likely values, say which values you took, and answer under them.

## Done when

It lands on a decision rule:

**X, because A and B dominate. Y instead, once C is true.**

If I need the mechanism rather than the decision, that is `/bro`.
