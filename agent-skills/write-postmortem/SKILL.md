---
name: write-postmortem
description: Write a blameless postmortem document from incident evidence, separating trigger, contributing conditions, mitigation, and durable remediation. Use after an incident is resolved, typically from investigate-incident findings; use investigate-incident for an incident still being diagnosed.
---

# Write a postmortem

Turn incident evidence into the document that prevents recurrence: a factual timeline, an honest causal analysis, and action items priced by the risk they retire.

## Inputs

Start from what exists: investigate-incident output, the incident channel, dashboards, and the change history.
Every claim in the document traces to one of these; anything remembered but unevidenced is marked as unconfirmed rather than silently promoted to fact.

## Blameless discipline

- Name systems, mechanisms, and conditions -- never a person as a cause. "The deploy pipeline allowed an unreviewed config change" is a finding; "X pushed a bad config" is not.
- Treat every operator action as reasonable given what the operator knew and saw at the time; when an action made things worse, the finding is what made it look correct.
- Counterfactuals ("this would have caught it") must name the mechanism and the evidence it would have fired; otherwise they are wishes, not action items.

## Shape

1. **Impact**: duration, affected users or systems, and cost in the units leadership uses (requests failed, revenue at risk, SLO budget burned). One paragraph.
2. **Timeline**: timestamped facts in UTC, from first causal change to full resolution, including detection lag and every escalation. Facts only -- analysis belongs below, and a timeline entry that argues is rewritten or moved.
3. **Causal analysis**, in the four categories investigate-incident distinguishes, kept distinct:
   - *Trigger*: the event that started this instance.
   - *Contributing conditions*: what had to already be true for the trigger to become an incident. This is usually where the durable findings live.
   - *Mitigation*: what stopped the impact, and why it worked.
   - *Durable remediation*: what removes the contributing conditions, as distinct from what merely handled this instance.
4. **Detection**: how long until a human knew, which signal fired or failed to, and whether a customer told us first.
5. **What went well, and where we were lucky**: both are real findings; luck is a contributing condition that happened to point the right way this time.
6. **Action items**: each with an owner role, a priority argued from recurrence risk times impact, and the contributing condition it retires. An action item that retires nothing is scope creep wearing an incident badge; cut it.

## Writing rules

- Final form: no meeting narration, no draft history.
- Distinguish fact, inference, and judgment explicitly; the timeline is fact-only, the analysis may infer, and each inference names its evidence.
- Semantic line breaks; follow the repository's postmortem location and template when one exists.

## Handoff

State which action items are filed where, and name anything the document leaves unconfirmed that further investigation could settle.
