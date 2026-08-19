---
name: write-agent-docs
description: |
  Author or edit documents that agents consume: skills, CLAUDE.md, AGENTS.md,
  and reference docs reached by pointers. TRIGGER when creating or revising a
  skill, an agent rules file, or an on-demand doc an agent will load. SKIP for
  documents whose audience is human (READMEs, ADRs, design docs).
---

Reference for writing any document an agent consumes: a skill, a rules file such as CLAUDE.md or AGENTS.md, a doc reached by a pointer.
The packaging differs; the writing does not.
The goal is a predictable **process** every run, not identical output.

## Context pointers

A **context pointer** is a reference held in the agent's context that names out-of-context material and encodes the condition for reaching it.
A skill's description is one; a line in a rules file naming a doc is the same object.
The pointer's wording, not its target, decides when the agent reaches the material and how reliably.
A must-have target behind a weakly worded pointer is a variance bug: sharpen the wording first, and inline the material only if sharpening fails.

A pointer does two jobs: state what the material is, and list the trigger branches (a branch is a distinct case the document handles).
Every word of an always-loaded pointer costs on every turn, so prune it harder than the body:

- Front-load the trigger word: the pointer is where it does its work.
- One trigger per branch; collapse synonyms that rename the same branch.
- Cut identity the body already carries.

## The two loads

Every document and pointer spends one of two budgets:

- **Context load**: the cost of always-loaded material on the agent's window, paid every turn whether or not it fires.
- **Cognitive load**: the cost on the human of remembering which documents exist and when to reach for each. Not a cost to minimize: it is the price of human agency. Spend it where human judgement matters.

Material reached only through a pointer escapes context load at the price of the pointer's own line.

## Information hierarchy

A document mixes **steps** (ordered actions) and **reference** (definitions, rules, facts consulted on demand).
Place each piece on a ladder ranked by how immediately the agent needs it:

1. **In-file step**: what the agent does, in order.
2. **In-file reference**: consulted on demand; a flat peer-set of rules is a fine arrangement, not a smell.
3. **Disclosed reference**: pushed to a separate file behind a pointer, loaded only when the pointer fires.

**Progressive disclosure** is the move down the ladder so the top stays legible.
The cleanest test is branching: inline what every branch needs, disclose what only some branches reach.
When a document has steps, undisclosed reference buries them and turns attending to them into a coin flip.

**Co-location** is the within-file companion: keep a concept's definition, rules, and caveats under one heading, so reading one part brings its neighbors.
Scattering fragments one meaning across many places; duplication repeats it -- both are failures.

**Sprawl** is the failure mode: a document too long even when every line is live.
The cure is the ladder: disclose reference, and split by branch or sequence so each path carries only what it needs.

## Steps and completion criteria

Every step ends on a **completion criterion**: the condition that tells the agent the work is done.
Two properties make it a lever:

- **Clarity**: can the agent tell done from not-done? A vague bound ("understanding reached") invites premature completion. Sharpen the bound first; only if it is irreducibly fuzzy and you observe the rush, hide later steps by splitting the sequence across a real context boundary (a handoff or sub-agent dispatch).
- **Demand**: how much the criterion requires. "Every modified model accounted for" forces thorough work where "produce a change list" does not. Demand also binds flat reference: "every rule applied" gives an all-reference document its exhaustiveness bar.

The strongest criteria are both checkable and exhaustive.

## Leading words

A **leading word** is a compact concept already in the model's pretraining that the agent thinks with while running the document (lesson, frontier, tracer bullet).
Repeated as a token, it anchors a region of behavior in few tokens by recruiting priors the model holds.
Prefer an existing word: a coined term recruits no priors and costs definition tokens.
Hunt for restatements a leading word retires: "fast, deterministic, low-overhead" collapses into "tight" (a tight loop).

**Negation** is the failure mode beside this lever: steering by prohibition drags the forbidden behavior into context and makes it more available.
State the positive target ("write one-line comments") so the banned behavior is never spoken.
A prohibition earns its place only as a hard guardrail you cannot phrase positively, and even then pair it with the positive target.

## Invocation

Choose per skill, trading the two loads:

- **Agent-invoked** (has a trigger-bearing description the harness always loads): pays permanent context load for autonomous discovery, and lets other skills reach it. Write the description as the skill's top-level context pointer, trigger branches and all.
- **Human-invoked only** (where the harness supports suppressing agent invocation): zero context load, but the human is the index that must remember it exists. A router skill that names the others and when to reach each cures the piled-up cognitive load once such skills multiply.

## Pruning

- Keep each meaning in a **single source of truth**: changing the behavior should be a one-place edit.
- The **environment** is a source of truth too (package scripts, config files, directory layout, help output). A document restating it is a cache, earning its load only when the lookup is expensive. Cache the unwritten convention, the reason behind a choice, the gotcha no config confesses; leave one-command lookups to the environment, where they cannot go stale.
- Check every line for **relevance**: exposition that never bears on the task, and lines gone stale, both go. Without pruning, the default fate is sediment: stale layers that settle because adding feels safe and removing feels risky.
- Hunt **no-ops** sentence by sentence: an instruction the model already obeys by default pays load to say nothing. The test is model-relative: settle disagreements by running the document, not by debate. When a sentence fails the test, delete the whole sentence. A leading word too weak to beat the default ("be thorough") is a no-op; the fix is a stronger word, not a different technique.
