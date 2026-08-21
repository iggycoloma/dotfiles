---
name: review-pr
description: |
  Review a change -- a pull request, a merge request, or the working diff -- for
  correctness, spec conformance, sequencing, observability, repo fit, and mechanism level, and name
  both the smallest correct change and the best available one. TRIGGER when the
  user mentions a PR or MR by number or URL, asks to "review PR" / "review MR" /
  "look at this change", or asks for a review of the current diff. SKIP for a
  security-specific deep dive (use audit-security), or when the unit under review
  is a subsystem rather than a change (use review-system). PRECEDENCE: when this
  and audit-security both match, prefer this; escalate to audit-security only on
  explicit request or when the whole change is security-focused. A diff always
  outranks review-system. A repo-provided skill covering change review for
  the current repository outranks this skill -- invoke that one, and use
  this only for what it does not cover.
---

Review a change against the applicable project instructions.

## Target

The target is the PR, MR, URL, number, or working diff named by the user.

- **Non-empty** -- a PR/MR number or URL.
  Fetch it with `gh pr view` / `gh pr diff`, or `glab mr view` / `glab mr diff` on a GitLab remote.
  Check `git remote -v` if it is not obvious which.
  If the higher-level subcommands seem insufficient, read the deployed `prompts/forge.md` for the active agent before reaching for `gh api` / `glab api` -- it covers what current `gh` and `glab` already expose.
- **Empty** -- review the working diff.
  Determine the base rather than assuming `main`: `git symbolic-ref refs/remotes/origin/HEAD`, or the project's config.
  Then read `git diff <base>...HEAD` for committed work **and** `git diff HEAD` for uncommitted work -- the range form excludes the working tree, so on a dirty tree it silently reviews the wrong thing.
  If both come back empty, say there is nothing to review and stop. Never emit the no-issues line for an empty diff: a clean review nobody earned is worse than no review.

## Skip if

Closed, already reviewed by you, or a pure dependency bump. Say so and stop.
Draft is not a skip -- an early review is what a draft is for.

## Review

Read the diff, then the surrounding code where the diff is not self-explanatory.
Check git history on the modified lines when behaviour *changed* rather than got added.

Judge against these, in order of how often they actually bite:

1. **Correctness for untested cases.** What input or state does this mishandle that the author's tests do not cover?
2. **Spec conformance.** When the change has an originating issue, ticket, or spec, read it before judging the diff. Three findings live here: a requirement that is missing or partial, behaviour the spec did not ask for (scope creep), and a requirement that looks implemented but does the wrong thing. Cite the spec line for each. A change can follow every convention and still implement the wrong thing -- conformance and correctness fail independently, so check both. If there is no spec, say so once and move on.
3. **Order.** Does this only work if something else merges first -- a config version, a cross-repo contract, a schema migration, a dependency widening, a secret? If so, is the predecessor named in the description? If it is not, that is a finding. Cross-repo ordering that lives only in someone's head inverts.
4. **Visibility.** If this breaks in production, does anything fire? Silent-failure paths -- a swallowed catch, a new code path with no log, metric, or span, a surface with no error reporting. A silent break survives for months, because nothing is counting.
5. **Evidence.** Does it change behaviour people already depend on? If so, did the author look at current usage first? Shipping into unmeasured territory is how a change gets rolled back rather than fixed.
6. **Repo fit, at both altitudes.**
   - *Which utility* -- logger, error type, config loader, test shape. Flag a new one where an established one exists, and ask whether it is deliberate.
   - *Which mechanism* -- grep for the primitive the diff introduces (an advisory lock, `SELECT ... FOR UPDATE`, `SERIALIZABLE`, a mutex, a lease, a dedupe table, a retry wrapper, a cache). If it appears nowhere else in the repo, it is a new pattern even when it reads as domain logic, and it gets the same "deliberate or accidental?" question. This is the altitude that gets missed, because a lock does not look like a "pattern" the way a logger does.
7. **Mechanism level.** Once a change is established as necessary, ask where its invariant lives. Invariants rank by durability, the same way documentation does:

   **schema constraint -> type -> application code -> runtime coordination**

   A constraint is a property of the data -- it holds for every writer forever, including a backfill and a human in a SQL console. A lock is a property of one code path and holds only while every writer remembers to take it. Prefer the highest rung that expresses the invariant *fully*, and flag a change that reached lower than it needed to. The failure mode is silent erosion, not a bug you can point at today.

   Do not assume the top rung is always available: a constraint cannot express a cross-row or cross-service rule, and a lock is the right mechanism for genuinely serializing work.

   "Right problem, wrong mechanism" is a legitimate finding. Name the specific alternative and what it costs -- not "consider X".
8. **Content levels.** Comments that narrate the edit rather than explain the code -- past tense, "now handles X", "updated to Y", or anything that only parses if you know the previous version. That belongs in the change description. Also flag a comment a rename would delete.
9. **Title and durability.** If the project squashes on merge with no commit-message template configured, **the title becomes the entire permanent commit message** -- check whether that is the case rather than assuming either way. Where it is, flag a title that will not stand alone in `git blame` in two years ("fix bug", "address feedback", "update parser"), or a missing ticket reference where the project uses one. Also flag load-bearing rationale that lives only in a branch commit body: squash deletes it, so it needs to be in the code or the description.

## Two changes, every review

Items 1-9 find defects in the change as written; each asks "is this wrong?" and admits only *keep* or *flag*. There is no verdict for *replace*. So run one more pass on the change as a whole, and answer both halves explicitly:

- **The smallest correct change** -- the minimal diff that fixes the actual problem. Usually what should merge.
- **The best available change** -- what you would do with nothing off-limits.

Rules for the second half, which is the one that gets skipped:

- It is allowed to be invasive. A migration, a new constraint, a deleted abstraction, a moved boundary, a rewritten call path. Do not pre-filter it for cost, for scope, or for whether the author will want to hear it. **Price it instead:** name it, name its blast radius, name what it retires.
- **Cap it at one.** This is a synthesis, not a wish list. Three "we could also" items is how a review gets skimmed.
- **Default non-blocking**, and say where it goes -- normally a follow-up ticket, not this change. It is blocking only when merging the minimal change makes the better one materially harder to reach: a migration that would have to be undone, an API shape that gets adopted before it is fixed, a pattern that will be copied.
- If the two halves are the same change, say so in one line. That is a real answer and the common one.

## Do not flag

- Anything CI catches: types, lint, format, tests, build. Do not run them either.
- Pre-existing issues on lines the author did not touch.
- Nitpicks a senior engineer would not raise.
- Missing test coverage or general code-quality observations, unless the project's instructions require them.
- Intentional changes that are part of the broader change.
- Issues the project silences deliberately (a lint-ignore with a reason).

## Verify before reporting

For each finding, ask whether it survives scrutiny: can you point at the specific input, state, or sequence that produces the wrong result? If not, drop it.
A short, correct review is worth more than a thorough one with two false positives -- those are what train people to skim reviews.

Mechanism and systems findings meet the same bar with different evidence.
There is no wrong output to point at, so point at the thing that already carries the invariant -- the constraint, unique index, type, or existing service -- and cite it by name and file.
Confirm it arbitrates *the same* case, not an adjacent one.
Without that you have a preference, not a finding, and it does not go in the review.

## Output

Report in the chat. Do not post to the forge unless explicitly asked -- compose the text and hand it over.

Label every finding **blocking** or **non-blocking**, explicitly. An unlabelled concern gets merged past. Do not add a third, softer tier: a "consider" or "nit" label is read as optional, which is the same as not raising it.

```
## Review: <change title>

Blocking
1. <one line> -- `path/to/file.ts:42`
   <why it is wrong, and the case that triggers it>

Non-blocking
2. <one line> -- `path/to/file.ts:88`
   <why>

Best available change
<the change, its blast radius, what it retires -- or "same as the diff"> -- <where it goes>
```

The `Best available change` section is always present, even when the answer is that the diff is already it.

If nothing survives verification: `No blocking issues. Checked correctness, spec conformance, ordering, observability, repo fit, mechanism level, and content levels.` Still answer `Best available change`.

No emojis. No attribution footer. Cite `path:line` for every finding.

## After the report: diligence, then drafts

The report is unchanged. What follows it is a separate `Suggested comments` section, produced
without being asked.

**Run diligence on the findings that survived verification.** Two passes:

*Prior art.* Check the change's own discussion, the referenced ticket and its comments, and team
chat for the mechanism by name. A finding the team already argued and dismissed reads as not
having done the homework, and it spends the author's willingness to read the next one. If the
ticket points at a spec or doc you cannot read, treat that as unknown rather than as an
all-clear -- say which section you couldn't see.

*Mitigations, one level down.* Any claim that something is already handled -- a framework default,
a cookie attribute, a header, a platform guarantee -- gets verified against this repo's actual
config before it appears anywhere. A half-true mitigation is worse than none: it tells the author
to relax about the half you got wrong. Separate what the mechanism guarantees from what merely
happens to be true of the current code, and state the residual gap alongside the protection.

Diligence can amend or kill a finding. When it does, fix the report before printing it -- a
finding already dispositioned upstream is not a finding, and a corrected mitigation changes how
severe the remaining risk is.

**Then draft.** One comment per finding that survives and that you would actually post: every
blocking finding, plus non-blocking ones whose reasoning won't compress to a single line. Skip
the mechanical ones. For anything diligence resolved, one line saying where it was settled
instead of a draft.

### Voice for a draft

A comment is a message to a colleague, not a section of the report. Lowercase and contractions
are fine. Aim for 60-90 words in one paragraph: mechanism and impact compressed together, with
the `file:line`. Only spell out the fix when it isn't obvious from the question.

- **Frame the whole comment as a verification request, not a verdict.** Hedge the reading
  ("if I'm reading it right"), and end by asking whether there's a path you missed rather than
  stating there isn't. The question should be answerable and worth answering -- usually "was this
  deliberate, or aimed at <the case it clearly gets right>?" -- because the author normally did
  have a reason and you want it before you argue with the choice.
- **Assume competence.** Name the case their choice gets right before the case it misses. You are
  asking about a tradeoff they made, not catching them out.
- **Plain words for impact, no dramatization.** Drop the protocol shorthand -- "can't quietly fire
  off actions on the operator's behalf" over "nothing POST-shaped can be ridden". The impact has
  to land for someone who doesn't hold the spec in their head; jargon there reads as showing work
  rather than explaining risk. No "the nasty part is..." framing -- state the consequence once and
  move on.
- **Merge timing in words, only when it isn't already clear.** "happy for this to be a follow-up"
  when severity is ambiguous -- never the blocking / non-blocking label, and never a softer verdict
  than the one in the report. Skip it when the severity is already unambiguous from the comment.
- **Don't narrate your own diligence.** The research keeps you from posting something already
  settled; it is not content for the comment. If you did miss prior art, the author will say so in
  their reply, and that costs nothing.
- **Never use "if you want it" or similar permission-granting phrasing.** Either name the fix
  plainly in one clause or leave it out.

Drafts are handed over, never posted. Publishing stays a separate, explicit ask.
