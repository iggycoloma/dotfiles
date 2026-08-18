---
name: investigate-incident
description: Investigate an active or recent production incident using telemetry, change history, timelines, and repository evidence; separate mitigation, trigger, contributing conditions, and durable remediation. Use for outages, degradations, security events, or customer-impacting production failures rather than locally reproducible bugs.
---

# Investigate an incident

Prioritize impact containment and reliable facts over an early root-cause story.

## Establish incident state

1. Record affected users, operations, regions, versions, start time, current status, and incident owner when known.
2. Distinguish active impact from recovery and retrospective analysis.
3. If impact is active, identify the safest reversible mitigation and the evidence needed to confirm it worked. Do not perform production mutations without explicit authority.
4. Build a timestamped fact table from available alerts, logs, metrics, traces, deploys, configuration changes, and operator actions.

Never imply access to production systems or evidence that was not provided or available through configured tools.

## Investigate

- Compare healthy and affected time windows, versions, regions, tenants, or request classes.
- Correlate symptom onset with deploys, migrations, dependency events, traffic changes, capacity limits, and control-plane changes.
- Trace the critical request or job path and identify where expected signals diverge.
- Form ranked hypotheses with confirming and falsifying evidence; test the cheapest discriminating hypothesis first.
- Preserve raw timestamps and sources. Mark inference, uncertainty, and clock or sampling limitations.

Separate:

- Trigger: the event that initiated the incident.
- Root cause: the condition that made the failure possible.
- Contributing conditions: factors that widened impact or delayed recovery.
- Detection gap: why the system or team did not learn sooner.
- Response gap: what made mitigation or diagnosis slower or riskier.

Avoid monocausal narratives when evidence supports an interaction of conditions. Do not use human error as a stopping point; identify the system condition that allowed one action to cause the impact.

## Remediation

Classify actions as immediate mitigation, permanent corrective action, detection improvement, response improvement, or risk acceptance. Each action needs an owner or owning system, verification, and the failure mode it retires. Prefer durable constraints and safe defaults over reminders and process alone.

## Output

Report current impact and mitigation first, then a timestamped timeline, evidence, hypotheses tested, causal analysis, and corrective actions. State confidence and unresolved questions. For a retrospective, include what worked and should remain unchanged. Do not publish an incident update or postmortem without explicit authorization.
