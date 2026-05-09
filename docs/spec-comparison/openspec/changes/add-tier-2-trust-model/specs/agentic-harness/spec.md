# agentic-harness -- Change Delta (add-tier-2-trust-model)

## ADDED Requirements

### Pre-flight estimation

- The harness MUST ship `agentic/scripts/ralph-estimate.sh`, a
  standalone tool that reads a PRD and prints a 5-line summary
  including suggested `--max-iterations`, `--session-budget`, and
  `--max-wall-clock` flags.
- `ralph-estimate.sh` MUST NOT call Claude. Estimates are heuristic
  only.
- `ralph-estimate.sh` MUST support `--json` for machine-readable
  output with keys: `tasks_total`, `tasks_remaining`,
  `suggested_max_iterations`, `suggested_session_budget_usd`,
  `risk_factors`.
- `ralph-estimate.sh` MUST identify risk factors in a PRD:
  long-running verify commands (`make test|npm test|cargo test|go
  test`), green-field tasks (descriptions referencing files not yet
  in the repo), and unverifiable tasks (no `verify` field).
- `ralph-estimate.sh` MUST exit 0 on success, 1 on missing PRD file,
  2 on malformed PRD.
- `agentic/scripts/ralph-spec.sh` MUST expose helpers:
  `spec_task_count`, `spec_done_count`, `spec_verify_commands`.

### Cross-loop discoveries

- ralph MUST support a `--with-discoveries` flag that activates
  cross-loop context sharing.
- When `--with-discoveries` is set, ralph MUST read
  `${XDG_STATE_HOME:-$HOME/.local/state}/ralph/discoveries/<project-sig>.md`
  during Phase 1 (Orient) and inject its contents into the iteration's
  context.
- The project signature MUST be computed as: (1) md5 of `git remote
  get-url origin`, falling back to (2) `basename <repo-root>-$USER`,
  falling back to (3) `unknown` (with warning).
- ralph MUST optionally append a one-line discovery during Phase 6
  (Record) when the iteration produced a learning above an operator-
  tunable threshold.
- Discovery appends MUST be `flock`-protected; when `flock` is
  unavailable the implementation MUST fall back to a plain `printf
  >>` append (relying on POSIX < PIPE_BUF atomic-write guarantee on
  Linux).
- Discovery lines MUST be one line each, < 4 KiB, to keep the
  unlocked fallback safe.
- Concurrent appends from N parallel ralph instances on the same
  project signature MUST not corrupt the file.

### Phased iteration mode

- ralph MUST support a `--phased` flag.
- When `--phased` is set, each iteration MUST execute three Claude
  prompts in sequence: plan, implement, review. Each prompt MUST
  share a per-iteration scratchpad.
- The default mode (single blob) MUST remain the default for
  backwards compatibility.
- Phased iteration time SHOULD be less than 2x single-blob iteration
  time on a no-op task (overhead bound).
- The final git graph for a smoke-test PRD MUST be identical between
  single and phased modes (functional equivalence on simple cases).

## MODIFIED Requirements

### Stack maturity targets

The previous spec referenced these target maturity scores
(implicitly via `agentic/planning/2026-04-19-unattended-stack-maturity.md`):

- Task Selection: 20% (current); no defined target.
- Context: 50% (current); no defined target.
- Loop / Execution: 75% (current); no defined target.
- Overall: ~72% (current); no defined target.

After this change, the spec MUST commit to the following post-Tier-2
targets in `agentic/planning/2026-04-19-unattended-stack-maturity.md`
(updated as part of this change):

- Task Selection: 50% (after 2A).
- Context: 70% (after 2B).
- Loop / Execution: 85% (after 2C).
- Overall: ~82%.

These are explicit acceptance criteria, not aspirational.

## REMOVED Requirements

(none -- this change is purely additive; Tier 1 surface unchanged)

---

## Notes for the reviewer

- All three additions are opt-in via flags; default ralph behavior is
  unchanged.
- No new dependencies (jq is already required; flock ships with
  util-linux on every Linux base image).
- Tier 1 safety gates (7 exit codes) MUST continue to fire unchanged.
- This change does NOT introduce a coordinator daemon or cross-machine
  sync (both deferred to Tier 3 or never -- see proposal.md "Out of
  scope").
- Constitution Article V (opt-in for high-risk surface) is respected:
  every Tier 2 feature requires an explicit flag. Constitution Article
  II (defense-in-depth) is respected: no new privileged surface, no
  new credential paths.
