---
name: draft-adr
description: Author an architecture decision record or RFC for a named decision, with evidence from the repository, alternatives priced fairly, and reversibility stated. Use when the user asks to write, draft, or document a design decision; use review-design to critique an existing document instead.
---

# Draft an ADR

Produce the document that review-design would accept: the decision in its final form, with the evidence and the rejected alternatives a future reader needs to avoid re-litigating it.

## Establish the decision

1. Identify the decision being made, its owner, and the forcing function. A document without a decision is a survey; say so and ask what is actually being decided.
2. Separate requirements and fixed constraints from preferences. A constraint cites its source (SLA, compliance, team capacity, an existing contract); anything without a source is a preference and is labelled as one.
3. Gather the evidence from the repository and history before writing: the mechanisms that exist today, what they cost, and what breaks if nothing changes. An ADR that cites no current code is an opinion piece.

## Shape

Follow the repository's existing ADR convention (location, numbering, template) when one exists; otherwise use `docs/adr/NNNN-<slug>.md` with:

1. **Context**: the problem, its evidence, and the constraints. Facts only; no proposed mechanism yet.
2. **Options**: each credible option including the status quo, priced with the same attributes -- implementation cost, operational cost, failure modes, exit cost. An option described more thinly than the favourite is a rigged comparison; flesh it out or drop it honestly.
3. **Decision**: one option, stated in a sentence, with the decisive attribute named. If the decision follows from the pricing, this section is short; if it needs a paragraph of argument, the Options section is hiding something.
4. **Consequences**: what becomes easier, what becomes harder, what is retired, and the new invariants someone must now maintain. Include the losing options' advantages that are being given up.
5. **Reversibility**: the conditions under which this decision should be revisited, and what reversing it would cost at that point. "Irreversible after the first production backfill" is a real answer; "we can always change it later" is not.

## Writing rules

- Final form, not lifecycle: no narration of drafts, meetings, or who proposed what.
- Distinguish observed facts, measurements, and judgment calls; do not flatten a qualified judgment into a categorical claim.
- Semantic line breaks, no hard column wrap, per the markdown conventions.
- Status field at the top: `Proposed` until review, then `Accepted` / `Superseded by NNNN`.

## Handoff

Name the open questions the draft deliberately leaves for review rather than resolving silently.
Offer review-design as the critique pass; the two skills are author and critic of the same artifact and are meant to be run in sequence.
