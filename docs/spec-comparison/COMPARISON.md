# OpenSpec vs SpecKit -- side-by-side comparison

This is the punchline doc. It assumes you have skimmed `README.md` for
orientation and that you have at least one example artifact open from
each side (e.g. `openspec/specs/unattended-harness/spec.md` next to
`spec-kit/specs/010-unattended-harness/spec.md`).

A note on naming: the capability now called `unattended-harness` was
originally `agentic-harness`. The repo subdirectory and capability
folder were renamed when PR #53 landed; this doc uses the new name
throughout except when referring to the historical archive entry
`archive/2026-04-15-extract-agentic-harness/`, which is intentionally
frozen at its original name. See section 6 -- the rename itself
becomes another OpenSpec refactor example.

The two formats both call themselves "spec-driven development"
toolkits. They diverge sharply on what a spec *is*, how it changes
over time, and what an AI agent does with it. This document walks
through the comparable artifacts produced from the same source code
(this dotfiles repo) and calls out where each format earns its keep
and where it gets in the way.

---

## 1. Executive summary

**OpenSpec** treats the spec as a behavior contract that lives next to
the code, and treats every change as a reviewable proposal with a
delta (ADDED / MODIFIED / REMOVED). The change folder is the unit of
work; the canonical spec absorbs the delta on archive. Strong fit for
**brownfield** -- when the spec emerges *from* an existing codebase
and changes are incremental.

**SpecKit** treats the spec as the *executable input* to an AI agent,
the constitution as a non-negotiable gate, and the plan as the place
where reality (technical context, complexity tracking) gets reconciled
with intent. The numbered feature folder is the unit of work; the
constitution is amended through its own ceremony. Strong fit for
**greenfield** -- when there is no code yet and the spec drives the
build.

For this dotfiles repo (a brownfield with 60+ commits, multiple
incremental refactors, capability extractions, a sandbox-posture
pivot, and an in-flight Tier 2 expansion), **OpenSpec was the more
natural fit**. The delta spec mechanism handled the agentic-harness
extraction, the back-compat symlink removal, the egress-script
removal (PR #53), and the capability rename cleanly; the change-
folder model mirrored the repo's existing PR cadence; the proposal
-> design -> tasks -> delta sequence maps neatly to how the work
actually happened. SpecKit's constitution + Constitution Check would
have caught a couple of constitution violations earlier, and its
T###/[P]/[USN] task structure is genuinely better for AI agents to
drive -- but the lack of a delta-spec primitive made the recent
"remove back-compat symlinks" PR and the "remove iptables egress"
pivot awkward to express (you re-author spec.md and bump constitution
version, with no obvious place for "what got removed" as a
first-class artifact).

The full case is in sections 6 and 11. Sections 2-5 set up the
vocabulary, then 6-10 walk through the actual artifacts, then 11-13
get to recommendations and what we would change about each.

---

## 2. Conceptual model

How each framework names the world:

| Concept                         | OpenSpec                                  | SpecKit                                          |
|---------------------------------|-------------------------------------------|--------------------------------------------------|
| Unit of behavior                | Capability (`openspec/specs/<name>/spec.md`) | Feature (`specs/NNN-<name>/spec.md`)             |
| Unit of work                    | Change (`openspec/changes/<name>/`)       | Feature folder; planning artifacts inside it     |
| Project-level worldview         | `project.md` (worldview, descriptive)     | `constitution.md` (principles, prescriptive)     |
| AI guidance                     | `AGENTS.md` (auto-maintained)             | Slash commands in `.specify/templates/commands/` |
| Behavior contract               | MUST/SHOULD requirements + GIVEN/WHEN/THEN scenarios | Functional Requirements (FR-###) + Acceptance Scenarios + Success Criteria (SC-###) |
| Change tracking                 | Delta spec (ADDED/MODIFIED/REMOVED)       | Re-author spec.md; constitution bump if needed   |
| Proposal-before-spec discipline | `proposal.md` is required first           | `/specify` produces spec.md directly; `/clarify` resolves ambiguities  |
| Validation                      | `openspec validate`                       | `/analyze` (read-only, severity-tagged)          |
| Task list                       | `tasks.md` (numbered N.M, no parallelism markers) | `tasks.md` (T### IDs, [P] markers, [USN] tags, phase gates) |
| Lifecycle terminus              | `archive/YYYY-MM-DD-<name>/`              | Branch merge; specs/NNN-* stays as historical record |

The two systems disagree about the *shape* of the world more than the
*existence* of the entities. Both have a project-level doc, a per-
feature spec, a planning artifact, and a task list. But OpenSpec
threads them through a change-folder lifecycle (propose -> design ->
tasks -> delta -> archive); SpecKit threads them through a phase
sequence (constitution -> specify -> clarify -> plan -> tasks ->
analyze -> implement).

This is the core asymmetry: **OpenSpec models *change*; SpecKit models
*phase progression***. Brownfield development is mostly a sequence of
changes. Greenfield development looks more like a phase progression.

---

## 3. Project-level docs side by side

Open `openspec/project.md` and `spec-kit/memory/constitution.md` next
to each other. They cover roughly the same surface (developer-
specific boundary, security model, cross-platform parity, idempotent
installs, opt-in for high-risk surface) but in totally different
voices.

### project.md (OpenSpec)

**Voice**: descriptive. "This is what the project is, what tech we
use, what conventions we follow."

**Sections**: Tech Stack, Architecture Patterns, Code Standards,
Domain Knowledge, Infrastructure, Known Constraints.

**How it's used**: `openspec/config.yaml` injects this content into
every artifact-generation prompt. The AI reads it as background
context. It does NOT gate work.

**Strength**: rich, narrative context. An AI new to the project can
read it and orient quickly. The "Domain Knowledge" section is
particularly useful for non-obvious things like the Claude Code hook
contract or the dc-audit profile distinction.

**Weakness**: not gated. If a proposal violates the "developer-
specific, not project-specific" principle, nothing in OpenSpec will
auto-flag it. The AI is *informed*, but the spec author still has to
notice.

### constitution.md (SpecKit)

**Voice**: prescriptive. "These are the articles you cannot violate
without amendment ceremony."

**Sections**: Core Principles (Articles I-V), Technology Requirements,
Development Practices, Governance.

**How it's used**: every `plan.md` has a Constitution Check section
that explicitly validates against each article. Violations require a
Complexity Tracking entry justifying the deviation. `/analyze`
reports constitution violations as CRITICAL severity.

**Strength**: gated. You cannot ship a plan without confronting the
constitution. The Tier 2 plan in this repo (see
`spec-kit/specs/010-unattended-harness/plan.md` Complexity Tracking)
explicitly justifies the cross-loop coordinator weakening of
isolation -- a discipline that would have been informal in OpenSpec.

**Weakness**: rigid. If the constitution gets out of date with the
code, every new plan inherits the staleness. Amendments require their
own version-bump ceremony, which is heavyweight for small projects.

### Verdict

For a *team* shipping multiple features per week, the constitution's
gating discipline is worth the rigidity. For a *solo* developer or a
small project where the worldview shifts naturally as the code does,
the descriptive `project.md` matches the pace.

This dotfiles repo is the latter. The OpenSpec `project.md` was
easier to author *because* it was descriptive -- I wrote down what the
repo does and why, not what the repo must always do. The SpecKit
`constitution.md` was harder because I had to commit to "non-
negotiable" articles for a single-developer project. Article V ("Opt-
In for High-Risk Surface") is genuinely non-negotiable; Article I
("Developer-Specific, Not Project-Specific") is more of a strong
preference, and turning it into a constitutional article that gates
every plan feels like over-formalization.

---

## 4. Capability spec side by side

Open `openspec/specs/unattended-harness/spec.md` and
`spec-kit/specs/010-unattended-harness/spec.md` next to each other.
Same source material, same ~30 requirements, different doc shapes.

### OpenSpec spec.md

```
# unattended-harness
## Overview
## Requirements
### Opt-in deployment
- The unattended harness MUST NOT deploy by default.
- The installer MUST deploy `~/.unattended/` only when ...
### Layout under ~/.unattended/
- The deployed `~/.unattended/` MUST contain ...
### ralph.sh: autonomous loop
- ralph.sh MUST run Claude Code in a loop driven by ...
### dc-audit.sh: devcontainer linter
- ...
## Scenarios
### Scenario: Default install does not deploy harness
GIVEN ... WHEN ... THEN ...
## Non-Behavior
- The harness does NOT deploy by default.
- ralph does NOT auto-merge or auto-push.
- ...
```

**Mental model**: the spec is a *catalog of requirements* grouped by
sub-area. Each requirement is a single MUST/SHOULD sentence.
Scenarios provide concrete examples but are explicitly secondary to
the requirements. The Non-Behavior section is a first-class part of
the spec -- explicitly listing what's NOT done is encouraged.

**Strength for this content**: The requirement-per-line structure
makes diffs surgical. When PR #47 removed back-compat symlinks, the
delta spec said "REMOVED: agentic payload in claude-code; REMOVED:
transitional back-compat symlinks". Reviewers see exactly what
disappeared.

**Strength**: Non-Behavior section. Forced me to write down "ralph
does NOT yet share context across parallel loops (called out as a
current gap)." That kind of explicit known-gap statement is rare in
SpecKit's user-story format.

**Weakness**: no priorities. All requirements look equally important.
A reader has no signal whether "ralph MUST run Claude Code in a loop"
is more critical than "ralph-parallel.sh MUST launch N ralph
instances on separate worktrees."

### SpecKit spec.md

```
# Feature Specification: Agentic Harness
## User Scenarios & Testing
### User Story 1 - Opt-in deploy via flag (Priority: P1)
**Why this priority**: ...
**Independent Test**: ...
**Acceptance Scenarios**: GIVEN/WHEN/THEN
### User Story 2 - Autonomous loop with safety gates (Priority: P1)
### User Story 3 - dc-audit lints devcontainer.json (Priority: P1)
### User Story 4 - Hardened unattended profile with mitmproxy (Priority: P1)
### User Story 5 - GH_TOKEN scope validation (Priority: P2)
### Edge Cases
## Requirements
### Functional Requirements
- FR-001 ...
- FR-002 ...
### Key Entities
- Iteration: orient -> plan -> implement -> verify -> commit -> learn cycle.
- Safety gate: a halt condition.
## Success Criteria
- SC-001 Default install does NOT deploy ~/.unattended/ ...
## Assumptions
```

**Mental model**: the spec is a *collection of user stories* with
priorities, plus a separate flat list of functional requirements
referenced by ID. Acceptance Scenarios live inside user stories;
Success Criteria are measurable outcomes.

**Strength for this content**: priorities. P1 stories (must ship to
call this Tier 1) are visually distinct from P2 (defense in depth
against over-scoped tokens). A reader scanning the spec immediately
sees "what's the MVP" -- it's the P1 set.

**Strength**: Success Criteria with measurable thresholds. SC-002
("ralph completes a 3-task PRD in <10 iterations") is explicit and
testable. OpenSpec's requirements are mostly binary; SpecKit's
SC-### entries can encode quantitative targets.

**Weakness**: User stories drift toward "what the developer does"
rather than "what the system does." User Story 1 ("opt-in deploy via
flag") is really about installer behavior, not user behavior. Forcing
it into the User Story shape ("a developer who runs Claude Code
autonomously...") adds boilerplate.

**Weakness**: FR-### and User Story acceptance scenarios overlap. A
reader has to consult both the user story's Acceptance Scenarios AND
the FR list to understand the full surface. OpenSpec collapses this
into one section.

### Verdict

For *behavior contracts* (what the system does, in MUST terms),
OpenSpec's catalog-of-requirements + Non-Behavior is cleaner. For
*shipping units* (what the team commits to building, in priority
order), SpecKit's prioritized user stories + measurable success
criteria is more actionable.

The asymmetry shows up most starkly in the Non-Behavior section --
SpecKit has no equivalent. Edge Cases captures *exceptional inputs*,
but there is no first-class section for "intentional non-behavior."
For a security-sensitive capability like unattended-harness ("ralph does
NOT auto-push", "the harness does NOT yet share context"), the
Non-Behavior section was load-bearing in OpenSpec.

---

## 5. Planning the same change in both

Open the in-flight Tier 2 work in both formats:

- OpenSpec: `openspec/changes/add-tier-2-trust-model/{proposal,design,tasks,specs/unattended-harness/spec}.md`
- SpecKit: there is no first-class equivalent. The closest is
  `spec-kit/specs/010-unattended-harness/plan.md` Complexity Tracking
  pointing at `tier-2-trust-model` as a future checklist (see also
  `spec-kit/specs/010-unattended-harness/checklists/security.md` Category 7).

This asymmetry is the most consequential one. Walk through it.

### OpenSpec: in-flight change folder

```
openspec/changes/add-tier-2-trust-model/
|-- proposal.md          # Why now, scope (in/out), approach, impact, acceptance
|-- design.md            # Architecture, key decisions w/ reason+trade-off, alternatives
|-- tasks.md             # Numbered checklist by phase
+-- specs/unattended-harness/spec.md   # ADDED requirements (delta)
```

The change folder *is* the unit. It lives outside the canonical
specs (which still describe Tier 1 as-built). Reviewers can read the
change folder in isolation, ask "do we want this?", approve or push
back, and only on `/opsx:archive` does the delta merge into the
canonical spec.

The Tier 2 ADDED Requirements include explicit new functional
requirements ("ralph MUST support a `--with-discoveries` flag"). They
do NOT yet appear in the canonical
`openspec/specs/unattended-harness/spec.md`. After archive, they will
appear there and the change folder moves to
`openspec/changes/archive/2026-MM-DD-add-tier-2-trust-model/`.

**Strength**: clean separation between as-built and proposed. A new
reader of the canonical spec sees only what currently exists; the
proposal lives in changes/ and signals "this is incoming work." The
delta spec format makes the diff trivial to review.

**Strength**: design.md captures *alternatives considered and
rejected*. The Tier 2 design.md spells out why a coordinator daemon
was rejected for Tier 2 (defer to Tier 3 or never). That kind of
"this was considered and rejected" reasoning has no first-class home
in SpecKit.

### SpecKit: in-flight work in plan.md + checklist

SpecKit doesn't have a "proposal" artifact. The closest equivalents:

1. **`plan.md` Complexity Tracking** -- a row noting "Tier 2 work in
   flight (NOT YET MERGED)" with the new constraint loosening
   (cross-loop coordinator weakens isolation). Rejecting alternatives
   gets a sentence in this row.
2. **`checklists/security.md` Category 7** -- "Tier 2 work (in
   flight)" checklist items: CHK021 ("Tier 2 work includes
   Complexity Tracking entry"), CHK022 ("Tier 2 does NOT loosen
   Tier 1 invariants").

The actual Tier 2 work, when ready to ship, would be done by:
- Updating spec.md to add new FR-###, SC-###, User Stories for the
  Tier 2 features.
- Updating plan.md to refresh the Constitution Check (does Tier 2
  still pass? where does Complexity Tracking grow?).
- Re-running `/tasks` to regenerate tasks.md with the new Phase Ns.
- Possibly amending the constitution if Tier 2 introduces a new
  permanent principle.

**Strength**: linear. Once Tier 2 ships, the spec.md / plan.md /
tasks.md trio reflects the as-built state. There's no separate
folder to merge or archive; the historical record is git history.

**Strength**: Complexity Tracking forces a contract about what
violations of the constitution Tier 2 would introduce. The OpenSpec
proposal has nothing analogous -- the design.md alternative-rejected
section is the closest, but it's narrative rather than structured.

**Weakness**: in-flight intent is not first-class. A new reader of
the spec.md sees the as-built state with no signal that Tier 2 is in
progress. They have to read plan.md Complexity Tracking and the
checklist to find out. Reviewers asked to "look at the Tier 2
proposal" have nothing to point at -- there is no Tier 2 proposal
artifact.

**Weakness**: spec.md, plan.md, and tasks.md are all going to need
non-trivial edits to absorb Tier 2. In OpenSpec, the change folder is
self-contained; in SpecKit, the Tier 2 work touches every existing
artifact.

### Verdict

**OpenSpec wins for in-flight tracking.** The change folder is a
clean unit that lives outside the canonical spec. SpecKit's
phase-progression model assumes the spec has caught up to reality;
when work is in flight, the lack of a first-class "this is proposed
but not yet built" artifact forces reviewers to triangulate from
plan.md hints and checklists.

If your team does a lot of in-flight work (most teams), or you ship
features behind feature flags, or you regularly have multiple PRs
exploring the same area in parallel, the OpenSpec change folder is
worth a lot.

---

## 6. Refactor / removal handling

Open the archived change folder in OpenSpec:
`openspec/changes/archive/2026-04-15-extract-agentic-harness/`. Note
that one of its delta specs
(`specs/claude-code-config/spec.md`) has a substantial `## REMOVED
Requirements` section. SpecKit has no analog.

### OpenSpec: REMOVED Requirements is a first-class section

The `claude-code-config` delta in this archive uses every part of the
delta vocabulary:

- `## ADDED Requirements`: empty (additions live in sibling deltas).
- `## MODIFIED Requirements`: one entry -- the deployment surface of
  `_setup_claude_code` shrunk.
- `## REMOVED Requirements`: two entries -- the agentic payload that
  moved out, AND the transitional back-compat symlinks that briefly
  existed and were then removed within the same change.

The `## REMOVED Requirements` section is *required* when something is
deleted. Reviewers reading the delta see the deletion as
prominently as the addition.

The "added then removed within one change" pattern -- where PR #46
introduced back-compat symlinks and PR #47 removed them -- is
captured cleanly: two REMOVED entries, one for the agentic payload
that moved permanently, one for the transitional symlinks that were
short-lived.

Two further refactors after that archive exercise the same primitives:

- **PR #53 (sandbox pivot)**: `bootstrap/devcontainer-egress.sh` and
  its `DOTFILES_DEVCONTAINER_EGRESS` / `DOTFILES_EGRESS_EXTRA_HOSTS`
  env vars were deleted. The attended-profile defense moved from
  iptables-at-runtime to dc-audit-at-spec-time. In OpenSpec this is
  a single REMOVED entry in `devcontainer-support/spec.md` plus a
  MODIFIED entry in `unattended-harness/spec.md` clarifying the
  attended/unattended posture split.
- **The agentic -> unattended rename** (modeled in
  `archive/2026-04-22-rename-agentic-to-unattended/`): a textbook
  paired-delta rename, with REMOVED in
  `specs/agentic-harness/spec.md` (every requirement gone) and ADDED
  in `specs/unattended-harness/spec.md` (every requirement restated
  under the new name). A reviewer sees the rename as a *behavior
  contract change*: same contract, new name, no scope shift.

### SpecKit: removals are implicit in spec.md edits

To express PR #47 in SpecKit, you would:

1. Edit spec.md, deleting the FR-### entries for back-compat symlinks.
2. Renumber surviving FR-### IDs (or leave gaps, depending on policy).
3. Update plan.md if the removal changes the technical context.
4. Update tasks.md if there were tasks tied to the removed
   requirements.
5. Possibly amend the constitution if the removal touches a principle
   (here it doesn't).

The git diff captures the deletion, but there's no first-class
artifact saying "we deleted X for reason Y." Reviewers have to read
the diff and infer intent from the commit message.

The PR #53 egress-script removal makes this gap concrete. In SpecKit:
the `devcontainer-support` spec gets edited (delete FRs for
`DOTFILES_DEVCONTAINER_EGRESS`); the `unattended-harness` spec gets
edited (add language about attended-vs-unattended posture); plan.md
gets a new Complexity Tracking row. None of these say "we deleted the
iptables script" as a first-class statement -- the deletion is
inferable from a diff but not visible in any spec artifact.

The capability rename (agentic -> unattended) is the same shape: a
SpecKit reviewer sees `mv specs/010-agentic-harness/
specs/010-unattended-harness/` in git and has to read commit messages
to know whether anything beyond the rename changed. In OpenSpec the
paired REMOVED + ADDED delta is the audit trail.

### Verdict

**OpenSpec is dramatically better for refactors and removals.** The
delta-spec REMOVED section is a first-class place to say "this used
to be required; here is what changed; here is why." SpecKit can
*technically* express this through edits and commit messages, but
the result is less reviewable.

For brownfield projects, where roughly a third of changes are
refactors or removals, this matters a lot.

---

## 7. Tracking execution

Open `openspec/changes/add-tier-2-trust-model/tasks.md` next to
`spec-kit/specs/010-unattended-harness/tasks.md`.

### OpenSpec tasks.md

```
## 1. ralph-spec.sh helpers
- [ ] 1.1 Add `spec_task_count(file)` ...
- [ ] 1.2 Add `spec_done_count(file)` ...
## 2. ralph-estimate.sh
- [ ] 2.1 Create `unattended/scripts/ralph-estimate.sh` (~150 lines).
- [ ] 2.2 Source `ralph-spec.sh` for helpers.
- [ ] 2.3 Implement heuristics: ...
## 3. discoveries.md plumbing
- [ ] 3.1 Add `discoveries_path()` to `ralph.sh`. ...
```

**Format**: numbered N.M (phase.subtask). Mark `- [ ]` for
checkbox. No parallelism markers, no story tags, no phase gates.

**Strength**: simplicity. A human reads this and knows exactly what
to do next. Ordering is implicit (1.1 before 1.2; phase 1 before
phase 2).

**Weakness**: not optimized for AI agents. An AI driving
implementation has to infer dependencies (do 1.1 and 1.2 share a
file? can they be parallel?). It can do this from context, but the
format doesn't help.

### SpecKit tasks.md

```
## Phase 1: Setup (Shared Infrastructure)
- [ ] T001 Initialize project structure
- [ ] T002 [P] Configure build tools
## Phase 2: Foundational (Blocking Prerequisites)
- [ ] T003 Create data models
## Phase 3: User Story 1 - Opt-in deploy (Priority: P1)
### Tests for User Story 1
- [ ] T008 [P] [US1] Test: ...
### Implementation for User Story 1
- [ ] T011 [US1] In _setup_agentic, deploy_configs ...
## Dependencies & Execution Order
### Phase Dependencies
...
### Parallel Opportunities
...
```

**Format**: T### IDs (zero-padded sequential). `[P]` markers for
parallelism. `[US#]` story tags. Phases are explicit. TDD enforced
(Tests before Implementation).

**Strength**: AI-driveable. An agent reading this can:
- Walk phases in order.
- Parallelize `[P]`-tagged tasks within a phase.
- Group tasks by user story for incremental delivery.
- Verify tests first, then implementation.

**Strength**: Dependencies & Execution Order section is *explicit*.
"Phase 3 blocks Phase 4" is stated, not inferred.

**Weakness**: verbose. The same work that takes 30 lines in OpenSpec
takes 80+ lines in SpecKit. For a human pair-reading tasks with the
team, this is more friction.

**Weakness**: T### IDs are stable but renumbering is painful. If you
insert T005 between T004 and T006, you either renumber everything (bad
for git history) or accept gaps (bad for cognitive load).

### Verdict

**SpecKit's tasks.md is better for AI agents to drive.** The phase
gates, [P] markers, [USN] tags, and explicit dependency notes give
an agent enough structure to coordinate parallel work without
guessing. For a Claude Code agent running `/implement`, it's
substantially better.

**OpenSpec's tasks.md is better for humans to read.** Numbered
`N.M` with no markers reads like a checklist; you scan it once and
know the plan.

If the same human reads tasks.md *and* an AI agent drives them, you
end up wanting both -- which is one of the few places where the two
formats genuinely diverge in usefulness.

---

## 8. Brownfield ergonomics

Both formats can be retrofitted to an existing repo. We tried both.
This section is the most opinionated.

### OpenSpec retrofit experience

The 12 capability specs in `openspec/specs/<cap>/spec.md` were each
authored by reading the relevant code and writing down "what does this
already do?" The Non-Behavior section forced me to write down "what
does this explicitly NOT do?" -- a useful exercise that surfaced
intentional design choices (no MCP servers by default, no workspace-
local state, no `--dry-run`).

The change folders (in-flight Tier 2, archived agentic-harness
extraction, the agentic -> unattended rename) were authored by
reading PR descriptions + commit messages + the actual diff. The proposal/design/tasks/delta separation
mapped cleanly to how the work was actually framed:
- proposal -> "what are we doing and why now?" (PR description)
- design -> "what's the technical approach?" (architecture decisions
  in the design discussion)
- tasks -> "what specific work?" (commit messages or task issues)
- delta spec -> "what changes about the contract?" (the FR-level
  diff)

For PR #47 specifically (back-compat symlink removal), the
`## REMOVED Requirements` section was load-bearing. The PR exists
*to remove* something; OpenSpec lets the spec doc say so. Same for
PR #53 (egress-script removal) and the agentic -> unattended rename
that landed alongside it.

PR #52 (host vs container settings variants) and the subsequent
`bin/settings-drift.sh` lint were also straightforward in OpenSpec:
add MODIFIED requirements to `claude-code-config/spec.md` and
`codex-config/spec.md` for the variant deployment contract; add a
new `## Requirements ### Settings drift` block to
`quality-gates/spec.md` for the lint. The "two files that must stay
in lockstep except for the sandbox block" shape is awkward in any
format -- OpenSpec at least lets you state it as a contract.

**Authoring time**: ~6 hours for 12 specs + 3 change folders
(extraction, Tier 2, rename).

### SpecKit retrofit experience

The 12 numbered feature folders required deciding on a sequence
(NNN-prefix). For a brownfield, the numbering is somewhat arbitrary
-- the capabilities aren't "first the install was added, then
packages, then shell." They all coexist. The numbering imposes a
narrative that isn't quite real.

The constitution.md required deciding which principles are
*non-negotiable*. For a single-developer project, declaring "Cross-
Platform Parity" as constitutional is partially aspirational --
there's no team to enforce it; the constitution is mostly a note to
future self.

The plan.md Constitution Check was the most consistently useful
SpecKit artifact. For each of the 12 capabilities, walking through
"does this respect each article?" surfaced exactly two violations
that needed Complexity Tracking entries (the two-layer security
duplication, the cross-cap dependency in 005-git-hooks). Both were
real design decisions worth recording.

The deep-dive trio (006, 009, 010) added research.md, contracts/,
data-model.md, checklists/. The research.md was the highest-value
optional artifact -- it captured "why we chose this" reasoning that
would otherwise live only in PR descriptions. The data-model.md
documented the rubric and allowlist schemas in a way the OpenSpec
spec.md couldn't easily fit.

For the in-flight Tier 2 work, the lack of a first-class proposal
artifact was awkward. I ended up putting the Tier 2 intent into
plan.md Complexity Tracking and a checklist; reviewers would have to
hop between three places to understand the proposal.

**Authoring time**: ~9 hours for 12 specs + 12 plans + 12 task files
+ 9 deep-dive artifacts.

### Verdict

**OpenSpec is faster and cleaner for brownfield retrofits.** The
descriptive project.md, the requirement-catalog spec.md, the change-
folder model -- all of these match how brownfield work is shaped.
The lack of mandatory phase ceremony is a feature, not a gap.

**SpecKit's higher ceremony pays off when there's an enforcement
loop.** The Constitution Check + Complexity Tracking is a real
review aid. The T###/[P]/[USN] tasks structure is a real AI-driving
aid. But on a brownfield retrofit done by one person, half the
machinery is overkill.

For *new features* on an existing codebase, the picture is more
balanced -- both formats produce useful artifacts. SpecKit's
`/clarify` step (resolve ambiguities one question at a time) is
particularly nice; OpenSpec has no equivalent.

---

## 9. Tooling and AI integration

### OpenSpec

- CLI: `openspec init`, `openspec list`, `openspec validate <change>
  --strict`, `openspec view <change>`, `openspec status`,
  `openspec instructions <change>`.
- Slash commands installed per-tool: `/opsx:propose`, `/opsx:explore`,
  `/opsx:new`, `/opsx:apply`, `/opsx:verify`, `/opsx:archive`,
  `/opsx:bulk-archive`. (Naming pattern: `opsx:` prefix.)
- AGENTS.md auto-maintained.
- Schemas customizable (`openspec schema fork spec-driven custom`).

**Strength**: validation tooling. `openspec validate --strict`
catches structural issues (missing sections, malformed deltas) before
review.

**Strength**: tool-agnostic. The slash commands install into Claude
Code, Cursor, Windsurf, Copilot, JetBrains, Continue. Each tool gets
its own command file under the appropriate directory.

### SpecKit

- CLI: `specify init`, `specify check`.
- Slash commands ship as templates: `/specify`, `/clarify`, `/plan`,
  `/tasks`, `/analyze`, `/implement`, `/constitution`. (Naming
  pattern: bare verbs, no prefix.)
- Templates customizable in `.specify/templates/`.
- `.specify/extensions.yml` for hook configuration (before/after
  each command).

**Strength**: phase enforcement. `/clarify` won't let you skip ahead
to `/plan` if there are unresolved `[NEEDS CLARIFICATION]` markers.
`/implement` won't run if checklists have uncompleted items.

**Strength**: the `/analyze` command is genuinely useful. Read-only,
non-destructive, severity-tagged findings against constitution + spec
+ plan + tasks coherence. OpenSpec's `validate` is more structural;
`/analyze` is more semantic.

### Verdict

**Both have credible integration stories.** OpenSpec's `opsx:` prefix
is a tasteful namespace choice; SpecKit's bare verbs are simpler but
collide with other tools' commands more often.

For *coherence checking* (does the plan actually implement the spec?
do tasks cover all FRs?), SpecKit's `/analyze` is meaningfully ahead.
For *structural validation* (is the delta spec well-formed?),
OpenSpec's `validate` is meaningfully ahead.

---

## 10. The constitution-vs-project-md axis

We treated this in section 3 but it deserves direct framing.

OpenSpec's `project.md` is **the developer telling the AI about the
project**. SpecKit's `constitution.md` is **the AI's principal
constraining the AI's behavior**.

This sounds like a small wording difference; it isn't. It changes the
power dynamic between the spec author and the AI agent.

In OpenSpec, the AI is informed but autonomous. It writes specs and
proposes changes; you review them. If a proposal violates
project.md's spirit, you push back as a reviewer. The framework helps
you frame the conversation but doesn't enforce.

In SpecKit, the AI is constrained. Constitution articles gate every
plan. If a plan violates an article, the framework forces a
Complexity Tracking entry justifying the deviation. You can still
override -- nothing prevents you from approving a plan with an
unjustified violation -- but the framework will not let the AI ship
silently.

For a team where the constitution genuinely *is* shared and
non-negotiable (regulated industry, security-critical systems), the
SpecKit model is the right call. For a solo project where "non-
negotiable" is mostly aspirational, the OpenSpec model has less
ceremony for the same effect.

Neither model is "right" in the abstract. The choice is a function of
*who you trust* and *what you'd accept being asked to justify*.

---

## 11. Recommendation matrix

Pick OpenSpec if any of these are dominant for you:

- **Brownfield project** with a meaningful change history. The delta
  model and change folders earn their keep here.
- **Frequent refactors / removals.** The `## REMOVED Requirements`
  section is genuinely missing from SpecKit.
- **Solo developer or small team** where heavy phase ceremony is
  overkill.
- **Existing PR cadence** where reviews already produce a propose ->
  review -> merge flow; OpenSpec maps onto this naturally.
- You want a doc you can write *as you go* without committing to
  non-negotiable principles upfront.

Pick SpecKit if any of these are dominant for you:

- **Greenfield project** where the spec drives the build.
- **Multi-person team** where the constitution genuinely is a shared
  contract.
- **High-velocity AI-driven implementation** -- you actually run
  `/implement` and want the framework to keep the agent honest.
- **Regulated context** where audit trails of "every plan justifies
  every constraint loosening" is a hard requirement.
- You want priorities (P1/P2/P3) and measurable success criteria
  (SC-###) as first-class artifacts.

Pick *both* if:

- Your project has a team writing greenfield features but a separate
  ops cadence doing brownfield refactors. Not as crazy as it sounds
  -- the formats coexist fine in different subdirectories.

Pick *neither* if:

- You're shipping <1 feature per month and the friction of writing
  *any* structured spec exceeds the value. Stick with PR descriptions
  and a CHANGELOG.

For *this dotfiles repo specifically*, OpenSpec was the better fit
-- mostly because of the brownfield retrofit nature of the
comparison exercise itself. Going forward, if I were starting Tier 3
of the agentic harness, I'd probably start with the SpecKit ceremony
(constitution, spec.md with FRs and SCs, plan.md with Constitution
Check) and only add OpenSpec change folders if Tier 3 produces
multiple in-flight changes simultaneously.

---

## 12. What I would change about each

### What I'd change about OpenSpec

1. **Add priorities to requirements.** OpenSpec's flat MUST/SHOULD
   list treats every requirement as equal. SpecKit's P1/P2/P3 user
   stories are visually striking and useful. OpenSpec could add a
   simple `[P1]` / `[P2]` tag to MUST requirements without changing
   the rest of the format.
2. **Add measurable success criteria.** SpecKit's SC-### entries
   ("install completes in <90s") give CI something to check.
   OpenSpec's spec.md has no obvious place for quantitative
   thresholds.
3. **Better validation of cross-spec dependencies.** If the
   `unattended-harness` spec references the `install` spec's
   `--with-unattended` flag, `openspec validate` should know that and
   flag a dangling reference if `install` removes the flag.

### What I'd change about SpecKit

1. **Add a first-class proposal artifact.** The lack of a
   `proposal.md` (or equivalent) for in-flight work is a real gap.
   Currently, in-flight intent gets squeezed into plan.md Complexity
   Tracking and checklists. A proposal.md would give it a home.
2. **Add a `## REMOVED Requirements` (or equivalent) section to
   spec.md.** Refactors and deprecations are first-class concerns,
   not implicit edits. SpecKit could add a section to spec.md (or a
   separate `removals.md`) without disrupting the rest of the format.
3. **Make T### renumbering optional.** A "stable IDs" mode that
   accepts gaps when tasks are deleted, vs a "renumber on save"
   mode for fresh specs. Currently every renumber decision is
   ad hoc.
4. **Reduce the redundancy between User Story Acceptance Scenarios
   and FR-### entries.** A reader has to consult both. Either fold
   them together, or make one explicitly the source of truth and the
   other a derived view.

### What both could borrow from each other

- **OpenSpec from SpecKit**: priorities, measurable success
  criteria, the `/analyze` semantic-coherence checker, the
  Constitution Check gate.
- **SpecKit from OpenSpec**: the proposal artifact, the `## REMOVED
  Requirements` delta primitive, the change-folder lifecycle, the
  Non-Behavior section, the descriptive (non-prescriptive) project
  context doc.

---

## 13. Closing

If you only read one section of this doc: **section 6** (refactor /
removal handling) and **section 5** (planning the same change in
both) are where the two formats actually diverge. Sections 3, 4, 7
are where they diverge in *style* but not in essential capability.
Sections 8 and 11 are the practical "what should I pick" sections.

The doc trees in `openspec/` and `spec-kit/` next to this file are
the primary evidence. Open them. The artifacts read very differently
-- not because one is better-written but because the formats want
different things from the spec author. You will quickly form your
own opinion about which trade-offs match your project; this document
is just the scaffolding for that conversation.
