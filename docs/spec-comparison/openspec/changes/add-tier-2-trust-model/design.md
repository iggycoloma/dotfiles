# Add Tier 2 Trust Model -- Design

## Overview

Three additions to the agentic harness, all opt-in and independently
shippable. Tier 1 (PRs #43-47) remains unchanged for users who do not
opt into Tier 2.

## Architecture

### 2A. ralph-estimate.sh (pre-flight estimate)

```
PRD.md  -->  ralph-spec.sh helpers  -->  ralph-estimate.sh
                  |                            |
                  +---- spec_task_count        +---- heuristics:
                  +---- spec_done_count               max_iter, budget,
                  +---- spec_verify_commands          wall_clock
                                                +---- risk-factor scan
                                                +---- text or JSON output
```

No Claude calls. Pure bash + jq. Standalone -- works without ralph.sh
running.

### 2B. discoveries.md (cross-loop context)

```
ralph iter --> Phase 1: Orient                     <-- read discoveries.md
ralph iter --> Phase 6: Record  --> flock-append   --> discoveries.md
                                       |                 ^
                                       v                 |
ralph (parallel sibling) iter --> Phase 1: Orient  ------+
```

File location: `${XDG_STATE_HOME:-$HOME/.local/state}/ralph/discoveries/<project-sig>.md`.

Project signature (first match wins):
1. `git remote get-url origin | md5sum | cut -c1-12`
2. `basename "$(git rev-parse --show-toplevel)-$USER"`
3. `unknown` (with warning)

### 2C. --phased mode (three prompts per iteration)

```
                  +---- plan_prompt    --> "What's the next 1-2 tasks?"
ralph iteration --+---- implement_prompt --> "Now implement the plan."
                  +---- review_prompt  --> "Self-review; spot regressions."
```

Default mode (single blob) unchanged. `--phased` activates the three-
prompt flow. Each sub-prompt has its own short context; iteration
overhead grows ~1.5x but quality on complex tasks improves.

## Key Decisions

### Decision 1: Estimate is heuristic, not LLM-based

**Chosen**: regex / counting heuristics for `ralph-estimate.sh`.

**Reason**: An LLM-based estimator would itself burn tokens and
introduce variance. Heuristics give a deterministic, free preview that
is "good enough" -- operator can override the suggested flags when the
PRD obviously violates the heuristic.

**Trade-off**: heuristic accuracy is bounded. Pathological PRDs (one
giant 100-line task) will be under-estimated. Acceptable: the operator
sees the PRD before running ralph and can spot the mismatch.

**Rejected**: an LLM call to Claude Haiku to estimate. Cost-positive
for trivial PRDs; latency adds friction; inconsistent across runs.

### Decision 2: discoveries.md is per-project, not per-machine global

**Chosen**: per-project signature scoping; lives at
`~/.local/state/ralph/discoveries/<sig>.md`.

**Reason**: Cross-project pollution is worse than missing context. A
discovery about project A's flaky test should not appear when ralph
runs on project B.

**Trade-off**: a developer with multiple repos has multiple discovery
files. Mitigated by the project-sig hash being deterministic and
short.

**Rejected**:
- One global `discoveries.md` -- pollutes context across projects.
- Per-branch discovery -- too narrow; loops on different branches of
  the same repo should share knowledge.

### Decision 3: `flock` for concurrent appends, with atomic-write fallback

**Chosen**: `flock`-protected append; fall back to plain `printf >>`
when `flock` is missing.

**Reason**: parallel ralph runs (`ralph-parallel.sh`) will append
concurrently. Without locking, lines can interleave. With `flock`,
writes serialize. The fallback exploits POSIX guarantee that writes
< PIPE_BUF bytes are atomic on Linux.

**Trade-off**: lines must stay under 4 KiB to keep the fallback safe.
Enforced by the recording template (one-line entries with a brief
finding + reference).

**Rejected**:
- `fcntl` via Python -- new runtime dependency.
- Append-only directory of per-iteration files -- explosion of small
  files; harder to read in Phase 1 Orient.

### Decision 4: --phased opt-in, default unchanged

**Chosen**: `--phased` flag activates the three-prompt mode; default
remains single-blob.

**Reason**: Tier 1 is the working baseline. Users who like its
simplicity should not be forced into the more elaborate flow.
Operators with complex PRDs opt in.

**Trade-off**: two code paths to maintain. The phased path largely
re-uses the same Claude invocation logic; only the prompt construction
differs.

**Rejected**: `--phased` as the new default -- breaks backwards
compatibility, slows trivial PRDs.

### Decision 5: NO coordinator daemon, NO cross-machine sync

**Chosen**: defer both to Tier 3 (or never).

**Reason**:
- A coordinator daemon would be a long-lived process holding state
  across loops -- new privileged surface, new failure mode if the
  daemon dies.
- Cross-machine discoveries sync would require pushing learnings to
  shared storage (S3, gist, etc.) -- privacy concern (learnings can
  contain code snippets), new credential.

**Trade-off**: parallel loops on the same machine share state; loops
on different machines do not. Acceptable for the current operator
profile (single developer).

**Rejected**: a daemon-based architecture would have been more
elegant for cross-loop coordination but the cost (new privileged
process, IPC layer) is not justified by the current scale.

## Implementation Strategy

### Phase 1: Estimate (2A) -- 2 days

1. Add `spec_task_count`, `spec_done_count`, `spec_verify_commands`
   helpers to `ralph-spec.sh`.
2. Write `ralph-estimate.sh` consuming the helpers.
3. Test fixtures with 0, 3, 10 tasks; all-done, some-done, none-done.
4. Add `--json` output mode.

### Phase 2: Discoveries (2B) -- 3 days

1. Add `discoveries_path()` helper computing the per-project file
   location.
2. Add `discoveries_read()` and `discoveries_append()` helpers
   (flock-protected).
3. Modify ralph's Phase 1 prompt to include discoveries content if
   `--with-discoveries` is set.
4. Modify ralph's Phase 6 prompt to optionally write a one-line
   discovery (operator-tunable threshold).
5. Concurrency tests: spawn 2 background ralph mocks doing 100
   appends each; assert no line corruption.

### Phase 3: Phased mode (2C) -- 4 days

1. Refactor ralph's iteration body to a function with a "prompt
   strategy" parameter (`single | phased`).
2. Implement `phased_iterate`: three Claude calls per iteration with
   shared per-iteration scratchpad.
3. Smoke test: run a 3-task PRD in both modes, assert same final
   git graph.
4. Performance test: phased mode iteration time should be < 2x
   single-blob.

### Phase 4: Integration -- 2 days

1. Update `agentic/README.md` documenting the three new flags.
2. Update `agentic/planning/2026-04-19-unattended-stack-maturity.md`
   with the post-Tier-2 score targets.
3. Run full `make test` matrix; expect green.
4. Run `bin/dc-audit.sh --strict` on the unattended profile; expect
   exit 0.

## Testing Strategy

- Unit tests in `tests/test-ralph.sh` for each new helper
  (spec helpers, discoveries helpers, phased iterate).
- Concurrency test for discoveries (2 mock ralph instances).
- Smoke test for `--phased` against a small PRD with passing verify.
- Risk-factor heuristic tests for `ralph-estimate` (PRDs that should
  trigger long-running, green-field, unverifiable flags).
- `--json` output validated with `jq empty` for shape conformance.

## Files

- Create: `agentic/scripts/ralph-estimate.sh`
- Modify: `agentic/scripts/ralph.sh`, `agentic/scripts/ralph-spec.sh`,
  `agentic/templates/PROMPT.md`, `agentic/README.md`,
  `agentic/planning/2026-04-19-unattended-stack-maturity.md`
- Modify: `tests/test-ralph.sh` (add Tier 2 suite)
