# Add Tier 2 Trust Model -- Proposal

## Intent

The Tier 1 unattended harness (PRs #43-47, renamed from "agentic harness" in #53) ships a working autonomous loop runner, devcontainer linter, and hardened unattended profile.
It does not yet handle three real-world gaps surfaced by `unattended/planning/2026-04-19-unattended-stack-maturity.md`:

1. **Task selection (20%)** -- ralph has no pre-flight estimation.
   An operator pointing ralph at a 30-task PRD discovers cost only after ralph has burned tokens.
2. **Cross-loop context (50%)** -- parallel ralph runs (ralph-parallel.sh) each maintain their own `progress.txt`.
   Discoveries made in one loop (a flaky test, a broken fixture, a working migration approach) do not reach sibling loops.
3. **Loop modality (75%)** -- the iteration loop is a single blob that does orient -> plan -> implement -> verify -> commit -> learn in one prompt.
   Splitting this into phased prompts (separate plan / implement / review prompts) would improve quality on complex tasks.

Tier 2 closes these gaps without weakening Tier 1's safety posture.

## Scope

In scope:

- New `unattended/scripts/ralph-estimate.sh` -- pre-flight cost / iteration estimate from a PRD.
- New `discoveries.md` cross-loop context file at `${XDG_STATE_HOME:-$HOME/.local/state}/ralph/discoveries/<project-sig>.md`.
- New `--phased` mode for ralph -- separate plan / implement / review prompts per iteration.
- Helpers in `unattended/scripts/ralph-spec.sh` for spec task counting and done-state inspection.
- Test coverage in `tests/test-ralph.sh` for all three additions.

Out of scope (Tier 3 candidates):

- Coordinator daemon for parallel loops (rejected for Tier 2 -- adds privileged process surface).
- Per-task fine-grained egress allowlists (rejected for Tier 2 --current allowlist is host-level which is sufficient for known tools).
- Cross-machine discoveries sync (rejected -- privacy implications, out of scope).

## Approach

Three independent commits, all behind `--phased` / `--with-discoveries` opt-in flags so Tier 1 behavior is unchanged for users who do not opt in.

1. **2A (estimate)**: standalone `ralph-estimate.sh` that does NOT call Claude.
   Pure parse + heuristic.
   Operator runs before `ralph.sh` to sanity-check the PRD.
2. **2B (discoveries)**: ralph reads `discoveries.md` at iteration start (Phase 1: Orient) and optionally appends at iteration end (Phase 6: Record).
   `flock`-protected; one-line entries < 4 KiB to keep the unlocked fallback atomic on Linux.
3. **2C (phased)**: new `--phased` flag splits each iteration into three sub-prompts.
   Default mode (single blob) remains the default for backwards compatibility.

## Impact

- **Operators using Tier 1 only**: zero behavior change.
  None of the Tier 2 features activate without opt-in flags.
- **Operators opting in**: significantly better cost predictability (estimate), shared learnings across parallel loops (discoveries), and quality on complex tasks (phased).
- **Constitution Article V** (opt-in for high-risk surface): respected -- every Tier 2 feature is opt-in.
- **Constitution Article II** (defense-in-depth): ralph-estimate introduces no new privileges; discoveries lives in user-only `~/.local/state/`; phased mode has the same trust boundary as single-blob mode.
- **No new dependencies**: jq is already required; `flock` is in util-linux on every Linux base image; no new bins.
- **Maturity scores** (target):
  - Task Selection: 20% -> 50% (after 2A)
  - Context: 50% -> 70% (after 2B)
  - Loop / Execution: 75% -> 85% (after 2C)
  - Overall: ~72% -> ~82%

## Acceptance Criteria

- `ralph-estimate.sh PRD.md` prints a 5-line summary including suggested `--max-iterations`, `--session-budget`, `--max-wall-clock`.
- `ralph-estimate.sh --json PRD.md` emits valid JSON with keys `tasks_total`, `tasks_remaining`, `suggested_max_iterations`, `suggested_session_budget_usd`, `risk_factors`.
- With `--with-discoveries`, ralph appends a one-line entry per iteration that produced a learning; sibling loops on the same project signature read the same file.
- Concurrent appends from two ralph instances do not corrupt the file (flock test).
- `--phased` mode runs three Claude prompts per iteration (plan, implement, review) and produces the same final commit graph as the single-blob mode for a smoke-test PRD.
- All Tier 1 safety gates (7 exit codes) still fire unchanged.
- `bin/dc-audit.sh --strict` on the unattended profile still exits 0.
- `make test` (test-ralph + test-dc-audit) is green on every matrix cell.
