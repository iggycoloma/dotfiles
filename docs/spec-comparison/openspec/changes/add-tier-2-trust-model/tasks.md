# Add Tier 2 Trust Model -- Tasks

## 1. ralph-spec.sh helpers

- [ ] 1.1 Add `spec_task_count(file)` returning total task count from PRD frontmatter.
- [ ] 1.2 Add `spec_done_count(file)` returning count of tasks with `done: true`.
- [ ] 1.3 Add `spec_verify_commands(file)` returning unique verify commands (one per line).
- [ ] 1.4 Follow existing `yq | awk-fallback` pattern at `ralph-spec.sh:112-137`.
- [ ] 1.5 Unit tests: empty PRD, 0/3/10 tasks, all-done / some-done / none-done.

## 2. ralph-estimate.sh

- [ ] 2.1 Create `unattended/scripts/ralph-estimate.sh` (~150 lines).
- [ ] 2.2 Source `ralph-spec.sh` for helpers.
- [ ] 2.3 Implement heuristics: `max_iterations = max(5, remaining_tasks * 2)` capped at `RALPH_ESTIMATE_MAX_ITER_CAP` (default 50); `session_budget = remaining_tasks * 0.6` USD; `max_wall_clock = max_iterations * 600` seconds.
- [ ] 2.4 Risk-factor scan: long-running verify (`make test|npm test|cargo test|go test`), green-field (description references missing files), unverifiable (no verify field).
- [ ] 2.5 Default text output: 5-line summary as in proposal.
- [ ] 2.6 `--json` output with keys: tasks_total, tasks_remaining, suggested_max_iterations, suggested_session_budget_usd, risk_factors.
- [ ] 2.7 Exit 0 on success; exit 1 on missing file; exit 2 on malformed PRD.
- [ ] 2.8 Tests: text mode, JSON mode, missing file, malformed PRD.
- [ ] 2.9 Document in `unattended/README.md` under "Three main entry points" section.

## 3. discoveries.md plumbing

- [ ] 3.1 Add `discoveries_path()` to `ralph.sh`.
  Computes `${XDG_STATE_HOME:-$HOME/.local/state}/ralph/discoveries/<sig>.md`.
- [ ] 3.2 Add `_project_signature()` (git remote md5 -> repo basename -> `unknown`).
- [ ] 3.3 Add `discoveries_read()` -- cat the file if it exists, else empty.
- [ ] 3.4 Add `discoveries_append(line)` -- flock-protected append; fall back to plain `printf >>` when flock missing.
- [ ] 3.5 Modify `unattended/templates/PROMPT.md` to inject discoveries content into Phase 1: Orient when `--with-discoveries` is set.
- [ ] 3.6 Modify Phase 6: Record to optionally call `discoveries_append` with operator-tunable threshold.
- [ ] 3.7 Add `--with-discoveries` flag to `ralph.sh` argument parser.
- [ ] 3.8 Concurrency test: spawn 2 mock ralph processes each doing 100 appends; assert all 200 lines present and non-corrupted.
- [ ] 3.9 Project-sig test: same repo across two checkouts -> same signature; different repos -> different signatures.
- [ ] 3.10 Document in `unattended/README.md`.

## 4. --phased mode

- [ ] 4.1 Refactor ralph's iteration body to call `iterate_strategy "$mode"` where mode is `single | phased`.
- [ ] 4.2 Move existing iteration logic into `iterate_single`.
- [ ] 4.3 Implement `iterate_phased`: prompt 1 (plan) -> prompt 2 (implement) -> prompt 3 (review), sharing a per-iteration scratchpad.
- [ ] 4.4 Add `--phased` flag to `ralph.sh` argument parser.
- [ ] 4.5 Update PROMPT.md template variants (one for plan, one for implement, one for review).
- [ ] 4.6 Smoke test: 3-task PRD, run in both single and phased mode, assert same final git graph.
- [ ] 4.7 Performance test: phased iteration time < 2x single-blob on a no-op task.
- [ ] 4.8 Document in `unattended/README.md`.

## 5. Integration & polish

- [ ] 5.1 Update `unattended/planning/2026-04-19-unattended-stack-maturity.md` with target scores (Task Selection 50%, Context 70%, Loop 85%, overall ~82%).
- [ ] 5.2 Update spec.md file in `openspec/specs/unattended-harness/` (after archive merges this change in).
- [ ] 5.3 Run `make lint`; expect 0 warnings.
- [ ] 5.4 Run `make test` (test-ralph + test-dc-audit included); expect green on every matrix cell.
- [ ] 5.5 Run `bin/dc-audit.sh --strict` on the unattended profile; expect exit 0.
- [ ] 5.6 Run a real autonomous loop end-to-end in the unattended profile (manual smoke test; not in CI).
