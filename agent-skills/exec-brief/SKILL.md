---
name: exec-brief
description: Translate a technical change, incident, decision, or risk into a short brief for a non-engineering audience, leading with business consequence and a concrete ask. Use when the user asks to summarize technical work for leadership, stakeholders, a board, or customers; not for engineer-to-engineer summaries.
---

# Write an executive brief

Produce the half page that lets a non-engineering reader make their decision or absorb their reassurance without needing the mechanism.

## Establish the audience and the ask

1. Name the audience and what they control: budget, headcount, a go/no-go, customer communication, or nothing (pure awareness).
2. Name the single thing the brief exists to produce: a decision (state the options), an approval (state the cost), or reassurance (state what was at risk and its current state). A brief with no ask and no reassurance is a status report; say so and ask which is wanted.
3. Ask what the audience already knows if it is not evident; re-explaining known context reads as padding, and skipping unknown context reads as evasion.

## Translation rules

- Lead with the consequence in the audience's units: money, time, customers, risk, obligations. The mechanism gets one sentence, and only if the ask depends on it.
- Convert every technical quantity into an impact quantity: "p99 latency doubled" becomes what the customer experienced; "we retired the legacy queue" becomes what stops breaking or costing.
- Keep honest uncertainty visible in plain words -- "we believe", "worst case", "confirmed" -- and never polish a qualified judgment into a categorical claim; a leader who acts on false certainty inherits the gap.
- No unexplained internal names: codenames, service names, and acronyms either translate or disappear.
- State dates and numbers absolutely; "next sprint" and "recently" do not survive forwarding.

## Shape

1. One-sentence headline: what happened or is proposed, and why the reader cares.
2. Consequence: impact so far and expected, in audience units. Two or three sentences.
3. The ask, or the reassurance, stated explicitly with its deadline or decision date.
4. Options with costs, when a decision is requested -- at most three, one line each, recommendation marked.
5. What happens with no action, one sentence: the honest default the reader is choosing by not deciding.

Half a page total.
When more depth exists, link or attach it rather than inlining; the brief must survive being read on a phone between meetings.

## Handoff

This is outward-facing speech: compose the full text, show it, and stop -- the publication policy governs where it may be sent and by whom.
Note anything simplified to the point a technical reader would object, so the user can judge the tradeoff before sending.
