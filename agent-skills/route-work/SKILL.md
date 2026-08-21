---
name: route-work
description: |
  Route the current situation to the right skill or chain of skills. TRIGGER
  when the user asks which skill fits, how to approach a piece of work, or
  what to do next in a workflow. SKIP when the user already named a skill,
  when another skill's TRIGGER already matches the request directly, or when
  the request is trivial enough to need none.
disable-model-invocation: true
---

# Route work

A router over the shared skill set: match the situation to a skill, say why, and hand off.
Do not perform the routed work here; name the skill, the reason, and what to bring into it, then invoke it or let the user do so.

Trivial work needs no skill: a one-line fix, a rename, a quick question.
Skills earn their overhead on multi-step work; say so when that is the answer.

## Checkpoints

Route by the phase transition the user is standing at:

| Situation | Route |
|---|---|
| Plan or idea with unstated assumptions or open decisions | grill-plan; too big for one session: plan-workstream |
| Feature agreed but not specced | specify-feature |
| Spec agreed but not decomposed | draft-tickets |
| Design question a discussion cannot settle | build-prototype |
| Building test-first | implement-tdd |
| Concrete failure: stack trace, failing test, wrong output | debug |
| Filed issue or ticket to address end to end | fix-issue |
| Merge or rebase stopped on conflicts | resolve-conflicts |
| Change ready for review (PR, MR, or working diff) | review-pr |
| Changes ready to record | commit; then create-pr |
| Release notes or changelog needed | generate-changelog |
| Ship or hold decision | assess-release |
| Old and new state must coexist across deployments | plan-migration |
| Production is broken or degraded | investigate-incident |
| Incident resolved, record needed | write-postmortem |
| Technical work needs a non-engineering summary | exec-brief |

## Standing questions

Not phase-bound; route on the question's shape:

| Question | Route |
|---|---|
| Is this subsystem built right? | review-system |
| Adopt, replace, or build this technology? | evaluate-technology |
| Record an architecture decision | draft-adr |
| Critique a design document before implementation | review-design |
| Outdated or vulnerable dependencies | manage-dependencies |
| Measured latency, memory, or throughput problem | optimize-performance |
| Security review of a repo, subsystem, or advisory | audit-security |
| Session ending mid-task, successor needs context | write-handoff |
| Writing or editing skills or agent rules files | write-agent-docs |
| Learn a topic interactively | teach-socratically |
| Forge conventions for descriptions, comments, API use | forge |
| Full supervised arc from spec to release assessment | run-pipeline |

## Chains

Each skill's output is the next one's input; when routing, name the chain so the handoff is explicit rather than hoped for:

- **Feature**: grill-plan -> specify-feature -> draft-tickets -> implement-tdd -> review-pr -> commit -> create-pr
- **Incident**: investigate-incident -> write-postmortem -> exec-brief
- **Big effort**: plan-workstream (decisions, one per session, via grill-plan / build-prototype) -> draft-tickets -> the feature chain per ticket
- **Systems finding**: review-pr's "right problem, wrong mechanism" -> review-system -> draft-adr or plan-migration

When two skills both match, the more specific unit wins: a diff outranks a subsystem (review-pr over review-system), a filed ticket outranks a described bug (fix-issue over debug), and a skill named by the user outranks this router.
