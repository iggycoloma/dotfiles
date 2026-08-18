# Forge interaction (PRs, MRs, issues, comments)

Conventions for working with GitHub and GitLab: fetching change context and writing anything the forge renders.
This file is deliberately not part of the always-loaded context.
Load it when a task touches a PR, MR, issue, or forge comment -- via the trigger line in the global instruction file, or via the `forge`, `review-pr`, and `pr-create` skills, which reference it.

## Forge CLIs: subcommands over raw API

Prefer purpose-built `gh` and `glab` subcommands over `gh api` / `glab api`.
Reach for `api` only when the higher-level CLI does not expose the required operation or data; when that limitation is not obvious, state it briefly.
Before using `api` for a common operation -- viewing diffs, commits, checks, pipelines, discussions, or metadata -- check the relevant `gh` or `glab` help first.
Do not preserve an API workaround merely because an older CLI version lacked the capability: current `glab` supports `mr diff` and `mr view --comments`, `--resolved`, and `--unresolved`, so those no longer justify `glab api`.

## Forge bodies do not hard-wrap

PR, MR, issue, and comment bodies on GitHub and GitLab render as GFM with hardbreaks enabled: every newline becomes a `<br>`, so a 72-column source displays as a narrow ragged column.
Let paragraph lines run long, or use one sentence per line; separate paragraphs with blank lines.
This is deliberately the opposite of the commit-message rule (~72-column body wrap), and applies only to text destined for the forge web UI -- `.md` files rendered from the repo do reflow and follow the semantic-line-break default in `engineering-conventions.md`.

## PR and MR descriptions

Describe the change in its final form, not the path taken to it.
The branch's commits already record how the work evolved and are the durable record of it; a description that also narrates the lifecycle duplicates that, ages badly, and buries what a reviewer actually needs.

- Write as though the change arrived in one step.
  No "bugs fixed along the way", no "addressed review feedback", no "the first attempt failed because".
- Keep it true of the final diff.
  Stale counts, superseded designs, and caveats that no longer apply are defects in the description, so update it when the branch changes.
- Review discussion belongs in review comments; the history of the work belongs in commits.
  Neither belongs in the description.

Shape, in this order, dropping any section that would be empty:

1. `## Summary` -- one sentence saying what the change makes the thing *become*, not what was done to it.
   Capability framing ("Expand X from A into B", "Replace X with Y"), no list, no rationale.
2. `## What changed` -- top-level bullets, each opening with an imperative verb (Add, Extend, Allocate, Strengthen, Replace, Remove) in the same form, nested at most one level for that bullet's specifics.
   Every bullet states a fact about the final state.
3. `## Safety and compatibility` -- only what a reviewer could otherwise get wrong: invariants still enforced, what stays backward compatible, breaking changes, and any deliberate choice that looks surprising without its reason.
   Short paragraphs rather than bullets.
4. `## Testing` -- the commands run and their results, one per line, no prose.
5. `## Known follow-up` -- what the branch deliberately leaves undone.

Bullets carry facts and prose carries only what a reviewer could misread, so a decision is never explained inside the change list; the reasoning that genuinely helps goes in Safety and compatibility, and everything else goes in the commit message.
Aim for a description a reviewer scans in under a minute before reading the diff: if a paragraph is arguing rather than stating, cut it or move it.
