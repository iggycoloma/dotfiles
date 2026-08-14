---
description: |
  Systems-level review of a subsystem: whether its invariants are enforced at the
  right level, and whether its shape is the one you would choose today. TRIGGER
  when the user names a subsystem, module, service, table, or capability and asks
  whether it is built right, whether the mechanism is correct, or what they would
  do differently with a clean slate. Also when a code review landed a "right
  problem, wrong mechanism" finding and the follow-up needs scoping. SKIP when the
  input is a diff, PR, or MR (review the change instead), when the question is a
  measured slowdown (use optimize), a readability or structure cleanup with no
  invariant at stake (use refactor), or a vulnerability hunt (use security-audit).
  PRECEDENCE: a diff always beats a subsystem -- if the user points at a change,
  review the change. This takes over only when the unit under review is the
  subsystem itself.
argument-hint: <path, module, service, or capability to review>
allowed-tools: Read, Grep, Glob, Bash(git log:*), Bash(git blame:*), Bash(git show:*), Bash(rg:*), Bash(fd:*), Bash(sg:*), Bash(scc:*)
---

Review a subsystem for whether its invariants are enforced at the right level, and whether its shape is the one you would choose today.

This is the counterpart to a code review, not a bigger version of one.
A code review takes a diff and asks whether the change is wrong.
This takes a subsystem and asks whether it is built right -- a question a diff cannot answer, because the diff's own boundary hides every writer it does not happen to touch.

## Target

`$ARGUMENTS` is a path, module, service, table, or named capability.
If it is missing, or names the whole repo, ask for a boundary before reading anything: an unbounded systems review produces a wish list, which is the failure mode this command exists to avoid.

State the boundary before starting -- what is in, what is out, and what you are treating as a fixed dependency.

## 1. Establish the invariants first

You cannot judge a mechanism without knowing what it must guarantee.
Derive the invariants from what is *enforced*, not from what is documented -- prose drifts, constraints do not:

- **Schema:** primary keys, unique and partial indexes, foreign keys, check constraints, not-null, defaults.
- **Types:** unions, branded or opaque types, required fields, narrowed signatures.
- **Tests:** what breaks tells you what someone intended to be true.
- **Error paths:** what the code refuses tells you what it assumes.

Write them down as a short list before evaluating anything.

**An invariant you cannot state crisply is itself the first finding.** It means the subsystem has a rule nobody wrote down, and every writer is guessing at it.

## 2. Enumerate every writer

This is the move a diff review cannot make, and it is where the real findings are.
Find every path that mutates the state, not just the ones on the happy path:

- Application call sites -- and whether they all go through one door or several.
- Background jobs, queue consumers, schedulers, retries.
- Migrations and backfills. These run once, bypass application code entirely, and are where invariants die.
- Admin tooling, scripts, and anything a human runs by hand against the store.
- Other services or repos touching the same store directly.

A mechanism at the application level is only as strong as its least disciplined writer.
Name the weakest one.

## 3. Rank the mechanism

Invariants rank by durability, the same way documentation does:

**schema constraint -> type -> application code -> runtime coordination** (lock, lease, queue, advisory lock, serializable transaction)

A constraint is a property of the data: it holds for every writer forever, including a backfill and a human in a SQL console.
A runtime lock is a property of one code path, and holds only while every writer remembers to take it.
Each rung down widens the set of ways the invariant can be violated without anything failing loudly.

For each invariant from step 1: which rung enforces it today, which is the highest rung that could express it *fully*, and what does the gap allow?
Check the answer against step 2 -- a rung is only valid if it covers every writer you found.

Do not assume the ladder always wants the top rung.
A constraint cannot express a cross-row or cross-service rule, and a lock is the right mechanism for genuinely serializing work.
The finding is a mechanism that reached *lower than it needed to*, not any use of a low rung.

## 4. Count the primitives

Grep the coordination and safety primitives the subsystem uses -- locks, leases, dedupe tables, retry wrappers, caches, feature flags, transaction isolation levels.
A primitive that appears exactly once in the repo is either a deliberate exception or an accident, and the two are indistinguishable in a diff.
Ask which.

## 5. Boundaries

- Does the subsystem own its data, or does something else read and write its store directly?
- Is there one door in, or has the interface eroded into several?
- What does it depend on that it should not, and what depends on it that should not?

## 6. Failure behaviour

For each invariant: if it is violated in production, what happens -- loud failure, silent corruption, or slow drift?
A low-rung mechanism with no detection is the most expensive combination there is, and worth saying so in those words.

## Evidence bar

A systems finding has no wrong output to point at, so it needs different evidence.
Each one must name at least one of:

- The constraint, index, type, or existing service that already expresses the invariant, cited by name and file -- and confirmation that it arbitrates *the same* case, not an adjacent one.
- The specific writer from step 2 that escapes the current mechanism.
- The concrete divergence between two paths that are supposed to agree.

Without one of those you have a preference, not a finding. Drop it.

## Do not

- Review a diff. If the user pointed at a change, this is the wrong command.
- Report performance findings without a measurement, or structure findings with no invariant at stake. Those are `optimize` and `refactor`.
- Propose a rewrite with no migration path. "Replace this with X" and "here is the order in which X is reachable without a flag day" are different claims, and only the second is worth reading.
- Pad the list. Five findings that each name a writer beat fifteen that name a preference.
- Recommend a change whose only justification is that it is more modern.

## Output

Rank by what the gap actually allows, worst first. Cap at five findings.

```
## Systems review: <subsystem>

Boundary: <in scope> | <out of scope> | <treated as fixed>

Invariants
1. <invariant> -- enforced at <rung>, by `path/to/thing:line`
2. ...

Findings
1. <invariant at risk> -- enforced at <current rung>, belongs at <target rung>
   Escapes via: <the writer or path that bypasses it>
   Change: <what to do>
   Costs: <blast radius, migration order, what it retires>

Leave alone
- <something that looks wrong and is not, and why>
```

The `Leave alone` section is not optional.
A systems review that finds only problems has not been calibrated, and what you decided *not* to flag is the most useful part of the record for whoever reads it next.

Report in chat.
Do not open a PR, MR, or issue -- compose the text and hand it over.
No emojis. Cite `path:line` for every claim.
