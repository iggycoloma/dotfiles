---
name: bro
description: Re-pitch the last answer as mechanism -- what is actually going on, and what I was missing. Fires only when the user types /bro.
disable-model-invocation: true
---

# Bro. Re-pitch that.

That did not land.
Unless I say otherwise, the gap is situational rather than conceptual: I know the technology, I do not yet know what it is doing *here*.
Start from what is specific to this system.

Arguments after the command name the part that failed; re-pitch that part.

## Re-pitch

**Name the mechanism.**
What causes what, in what order, and where the behavior actually comes from.

**Rank the details.**
Several things are true; one or two of them produce the behavior.
Lead with those and drop the rest.

**Say the assumption.**
The previous answer rested on something unstated -- a default, a version, a layer, a piece of my situation that got filled in.
Name it.

**Ground it** when the mechanism is easier to see than to describe: a request path, a data flow, a state transition, the failing case, a before/after, ten lines of the real code.

**Translate.**
Where a pattern name, product name, or abstraction stood in for the mechanism, say the same thing in ordinary engineering language.

If the thing is genuinely subtle, say what makes it subtle.
That is the answer, not a preamble to it.

## Done when

I can say "oh, THAT is what is going on."

The re-pitch is shorter than the answer it replaces.
The same claims at lower resolution is a restatement; a smaller, different set of claims is a re-pitch.

If what I want is the decision rather than the mechanism, that is `/cto`.
