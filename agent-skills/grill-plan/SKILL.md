---
name: grill-plan
description: |
  Stress-test a plan, design, or decision through a relentless structured
  interview that surfaces every open question before work starts. TRIGGER when
  the user asks to be grilled, interviewed, or challenged on a plan, or wants
  every assumption in a proposal made explicit before committing. SKIP when the
  user wants a written critique of an existing design document (use
  review-design) or a spec produced from a settled idea (use specify-feature).
---

Interview the user until you reach a shared understanding of the plan.
Map the open decisions as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**.
The **frontier** is every decision whose prerequisites are already settled: the questions you can ask now without guessing at answers you have not heard yet.
Ask the whole frontier in one round: number each question and give your recommended answer.
Then wait for the user's answers before the next round.

Format each question as:

```
Q1 - <question title>
<question body, possibly multiple paragraphs, including multiple choices where they help>
Recommended: <your recommended answer>
```

Each round of answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them.
Recompute the frontier and ask the next round.
A question whose answer depends on another question still open in this round belongs to a later round, not this one.

Finding **facts** is your job, never the user's.
When a frontier question needs a fact from the environment (the codebase, config, tooling, documentation), look it up or dispatch a sub-agent; do not ask the user for anything you could find yourself.
Do not block on lookups: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait; ask the rest of the frontier now.
The **decisions** are the user's: put each one to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed.
Do not act on the plan until the user confirms the shared understanding is reached.
Close by summarizing the settled decisions in one compact list the user can carry into specify-feature, draft-adr, or implementation.
