# Tier 2 and Beyond -- Agentic Harness Roadmap

Written to survive a context clear. A session starting fresh from `main` with no prior conversation history should be able to pick up from this file.

## Current state (all merged into `main`)

PRs shipped in order: `#42` (gh-repo-policy) -> `#43` (ralph harness + unattended hardening + verification gating) -> `#44` (Tier 1 sandbox/spec/observability) -> `#45` (dc-audit) -> `#46` (P1/P2 separation: `agentic/` subdirectory + opt-in install) -> `#47` (removed transitional back-compat symlinks).

What lives where:

- **P1 (dotfiles / terminal QoL)** -- `install.sh`, `bootstrap/{detect,packages,symlinks,completions,logging}.sh`, `shell/`, `config/`, `git/`, `vim/`, `tmux/`, `codex/`, `copilot/`, `claude-code/{CLAUDE.md,settings.json,statusline.sh,agents/,commands/,hooks/}`.
- **P2 (agentic harness)** -- `agentic/{scripts,templates,bootstrap,planning}/`, `agentic/{devcontainer-rubric.json,egress-allowlist.txt,README.md}`, `.devcontainer/unattended/`, `bin/dc-audit.sh`.
- **Shared** -- `bootstrap/logging.sh` (15+ call sites), `bin/gh-repo-policy.sh`, `tests/` (one test dir for everything), `Makefile`.

Install is opt-in for the agentic side: `./install.sh --with-agentic` or `DOTFILES_INSTALL_AGENTIC=1`. The unattended devcontainer profile sets this in `containerEnv`.

Stack maturity scores (from `agentic/planning/2026-04-19-unattended-stack-maturity.md`):

| Layer | Score | Notes |
| --- | --- | --- |
| Spec | 85% | YAML frontmatter with per-task verify; `ralph.sh --spec-file`. |
| Loop/Execution | 75% | Single-mode blob; `--phased` plan/implement/review missing. |
| Context | 50% | `progress.txt` per-loop only; no cross-loop state. |
| Verification | 95% | `--verify-cmd` gates `## COMPLETE`; revert-on-red in PROMPT.md. |
| Sandbox | 85% | Hardened unattended devcontainer with mitmproxy egress allowlist. |
| Guardrails | 90% | Iteration cap, wall-clock, per-iter timeout, circuit breaker, git checkpoint. |
| Observability | 75% | JSONL run log, cost tracking, `--session-budget`, summary table. |
| Task Selection | 20% | No pre-flight estimation of a PRD. |

---

## Tier 2 -- Next three items

All three are independent. Recommended shipping as **one PR on branch `feat/tier-2-context-phased-estimate`** with three commits (2A, 2B, 2C in order of increasing size).

### 2A -- Complexity estimation (Task Selection 20% -> 50%)

**Goal.** A pre-flight read of a PRD that tells the operator "expect ~N iterations, ~$M cost, here are the risk factors" before ralph burns tokens on an oversized spec.

**Deliverable.** New `agentic/scripts/ralph-estimate.sh` (standalone, ~150 lines). Reads a spec file and prints:

```
Ralph pre-flight estimate for PRD.md
  Spec version:     1
  Tasks:            7 total (0 done, 7 remaining)
  Verify commands:  7 unique
  Heuristic:        ~1-2 iterations per task, ~$0.30-$0.80 per iteration
  Suggested flags:  --max-iterations 18  --session-budget 8  --max-wall-clock 7200
  Risk factors:
    - 2 tasks use `make test` (long-running; expect iteration-timeout headroom)
    - 1 task references a file not yet in the repo (green-field)
  Not a ceiling -- actual cost depends on model + task complexity.
```

`--json` flag for machine-readable output.

**Implementation.**

- Extend `agentic/scripts/ralph-spec.sh` with two helpers, following the existing `yq | awk-fallback` pattern around lines 112-137:
  - `spec_task_count(file)` -- total tasks
  - `spec_done_count(file)` -- tasks with `done: true`
- New `agentic/scripts/ralph-estimate.sh` sources `ralph-spec.sh`, parses a spec, applies rule-based heuristics:
  - `max_iterations = max(5, remaining_tasks * 2)` capped at `RALPH_ESTIMATE_MAX_ITER_CAP` (default 50).
  - `session_budget = remaining_tasks * 0.6` (USD; tunable via env).
  - `max_wall_clock = max_iterations * 600` (10 min/iter).
- Risk-factor heuristics (all cheap, regex-based):
  - Count tasks whose `verify` matches `make test|npm test|cargo test|go test` -> "long-running".
  - Count tasks whose `description` references files missing from the repo -> "green-field".
  - Flag tasks without a `verify` field -> "unverifiable".
- No new dependencies.

**Tests.** Extend `tests/test-ralph.sh`:

- `spec_task_count` / `spec_done_count` on fixtures with 0, 3, 10 tasks and all-done / some-done / none-done states.
- `ralph-estimate.sh` exits 0 with a spec; exits 1 with a missing file.
- `ralph-estimate.sh --json` emits valid JSON with keys `tasks_total`, `tasks_remaining`, `suggested_max_iterations`, `suggested_session_budget_usd`, `risk_factors`.

**Files.**

- Create: `agentic/scripts/ralph-estimate.sh`
- Modify: `agentic/scripts/ralph-spec.sh` (two helpers)
- Modify: `tests/test-ralph.sh` (estimate suite)
- Modify: `agentic/README.md` (document the script)

### 2B -- Cross-iteration context (Context 50% -> 70%)

**Goal.** Parallel ralph runs and resumed sessions share learnings. Distinct from per-loop `progress.txt`, which carries one loop's journey; `discoveries.md` carries cross-loop project wisdom.

**Deliverable.** Machine-wide per-project `discoveries.md` that each loop reads at iteration start (Phase 1: Orient) and optionally appends to at iteration end (Phase 6: Record), protected by `flock`.

**Location.** `${XDG_STATE_HOME:-$HOME/.local/state}/ralph/discoveries/<project-sig>.md`.

**Project signature.** First match wins:

1. `git remote get-url origin | md5sum | cut -c1-12` -- stable across machines for the same repo
2. `basename $(git rev-parse --show-toplevel)-$USER` -- fallback when no remote
3. `unknown` -- final fallback (logs a warning)

**Locking.** Bash FD-based `flock`:

```bash
discoveries_append() {
    local line="$1" file="$2"
    mkdir -p "$(dirname "$file")" 2>/dev/null || true
    if command -v flock &>/dev/null; then
        (
            flock -x 9
            printf '%s\n' "$line" >> "$file"
        ) 9>"${file}.lock"
    else
        # Best-effort atomic append. POSIX guarantees atomic writes < PIPE_BUF.
        printf '%s\n' "$line" >> "$file"
    fi
}
```

One-line entries (< 4 KiB) so the unlocked fallback is still atomic on Linux.

**Implementation.**

- Extend `agentic/scripts/ralph.sh`:
  - Add `project_sig()` near `generate_session_id`.
  - Add `discoveries_append()` helper.
  - Compute `DISCOVERIES_FILE` at the top of `run_loop()`, create the directory.
  - Add `{{DISCOVERIES_FILE}}` token to `render_prompt()` (near line 413).
  - Log the discoveries path in the run banner.
- Extend `agentic/templates/PROMPT.md`:
  - Phase 1 (Orient): add a step to read `{{DISCOVERIES_FILE}}` if present.
  - Phase 6 (Record): append one short, non-sensitive learning. Explicit guidance: no credentials, no secrets, no verbose tracebacks. Prefix with `YYYY-MM-DD` and the repo-relative subsystem when relevant.
- Extend `agentic/scripts/ralph-parallel.sh`:
  - Existing design already gives each loop its own worktree + `progress.txt`. For 2B, just ensure `DISCOVERIES_FILE` resolves to the same project-sig file across loops (it will, because `project_sig` reads the repo remote, which is identical across worktrees). Log the shared path.

**Tests.** Extend `tests/test-ralph.sh`:

- `project_sig` prints a non-empty stable string in a repo; prints `unknown` outside.
- `discoveries_append` creates the directory + file and appends a line.
- Concurrency: spawn two background shells that each append 50 lines; verify the final file has exactly 100 lines. Gated on `command -v flock`; passes with a skip-message otherwise.
- `render_prompt` substitutes `{{DISCOVERIES_FILE}}` correctly.

**Files.**

- Modify: `agentic/scripts/ralph.sh` (helpers + render_prompt + run banner)
- Modify: `agentic/scripts/ralph-parallel.sh` (log the shared path)
- Modify: `agentic/templates/PROMPT.md` (Phase 1 and Phase 6 updates)
- Modify: `tests/test-ralph.sh` (discoveries suite)
- Modify: `agentic/README.md` (document the mechanism)

### 2C -- `--phased` ralph mode (Loop/Execution 75% -> 90%)

**Goal.** Autonomous plan -> implement -> review refinement in a single ralph run. Distinct from `claude-code/commands/pipeline.md` (which is human-gated multi-stage with subagents).

**Deliverable.** New `--phased` flag. When set, ralph runs three sequential passes with phase-specific PROMPT templates. Each phase is a full ralph loop with its own iteration budget, verify gate, checkpoint, and circuit breaker -- just a different template.

- **Plan phase.** Reads the PRD, produces `plan.md`, commits it. Default: 3 iterations.
- **Implement phase.** Reads `plan.md` + spec, executes tasks. The canonical ralph behavior. Default: `MAX_ITERATIONS`.
- **Review phase.** Reads the diff since `plan.md` was committed, runs a qa-reviewer-style pass, writes `review.md`. No code changes. Default: 2 iterations.

Exit on first failed phase. A failed review still leaves the implement phase's commits standing.

**Implementation.**

- Refactor `run_loop()` into `run_loop_core(prompt_file, max_iterations)` -- the existing body parameterized.
- Add `run_phased_loop()` wrapper that calls `run_loop_core()` three times in sequence, stopping on first non-zero return.
- New flags: `--phased`, `--max-iterations-plan N`, `--max-iterations-implement N`, `--max-iterations-review N`.
- `{{PHASE}}` token added to `render_prompt()` so phase-specific templates can branch messaging.
- Shared `progress.txt` across phases; append phase markers (`## Phase: Plan (iterations 1-3)`, ...).
- Aggregate summary after all phases complete: cumulative iterations, cost, per-phase verify counts.
- Tasks keep a single `done` flag (Option A from exploration); phases are a prompt-rendering detail, not spec schema.

**New PROMPT templates.**

- `agentic/templates/PROMPT-plan.md` -- instructs the agent to output `plan.md`, not code.
- `agentic/templates/PROMPT-implement.md` -- ~ the current `PROMPT.md` with Phase 1 also reading `plan.md`.
- `agentic/templates/PROMPT-review.md` -- instructs the agent to read the diff, write `review.md`, not modify other files.

`agentic/templates/PROMPT.md` stays as the non-phased default (don't break existing runs).

**Tests.** Extend `tests/test-ralph.sh`:

- `--help` mentions `--phased` and the three per-phase iteration flags.
- Arg validation on non-numeric values.
- Template assertions for the three new files (placeholders present, references to plan.md/review.md where expected).
- Sourcing `ralph.sh` and calling `run_loop_core` with explicit args works (extends the existing source-and-test pattern).
- End-to-end functional test with a mock `claude` binary is optional and heavy; could defer to a follow-up.

**Files.**

- Create: `agentic/templates/PROMPT-plan.md`, `PROMPT-implement.md`, `PROMPT-review.md`
- Modify: `agentic/scripts/ralph.sh` (flags, `run_loop_core`, `run_phased_loop`, `{{PHASE}}`, aggregate summary)
- Modify: `tests/test-ralph.sh` (phased suite)
- Modify: `agentic/README.md` (document `--phased`)

### Tier 2 shipping

- Branch: `feat/tier-2-context-phased-estimate`
- Three commits on the branch (2A, 2B, 2C). One PR.
- Tests ~100 new assertions across the ralph suite.
- Verify: `make lint && make test` clean. `agentic/scripts/ralph-estimate.sh agentic/templates/PRD.md` prints a sane report. `ralph.sh --help` mentions `--phased`. Concurrency test passes on Linux.
- End-to-end manual check (deferred, optional): run `ralph.sh --phased --spec-file` against a trivial 2-task PRD with `verify: "true"` and confirm `plan.md` -> commits -> `review.md` -> `## COMPLETE`.

---

## Post-Tier-2 backlog

Grouped by theme. Each one is a separate small PR.

### Validation

- **V1. Live unattended devcontainer smoke.** Actually build `.devcontainer/unattended/`, run mitmproxy, confirm it blocks a non-allowlisted host and logs allowlisted requests. Run `ralph.sh` against a trivial 2-task spec with `verify: "true"` and confirm the full chain (install.sh --with-agentic, unattended-deps, unattended-proxy, ralph, JSONL log). Document findings in a new `agentic/planning/` doc.
- **V2. End-to-end `--phased` smoke** (post-2C). Trivial 2-task PRD run through plan -> implement -> review with `verify: "true"`. Confirm `plan.md` + `review.md` artifacts.

### dc-audit expansions

- **D1. CI workflow.** GitHub Actions job that runs `dc-audit --strict --json` on any PR that touches `.devcontainer/`. Fail the check on errors; post findings as a PR comment for warnings. Deferred from PR #45's follow-ups.
- **D2. More rules.** Add `hostRequirements` (cpu/memory/storage), `forwardPorts.onAutoForward`, digest-pin support (warn when tag used but digest available), `customizations.vscode.extensions` recommendations, `features.init-order` when multiple features interact.
- **D3. `/harden-devcontainer` skill.** Wraps `dc-audit` with Claude's judgment: reads the target repo, detects `package.json` / `Cargo.toml` / `go.mod` / `pyproject.toml`, suggests appropriate features + VSCode extensions, proposes a diff. Lives at `claude-code/commands/harden-devcontainer.md` since it's a user-invokable skill, not an agentic harness component.
- **D4. Template library.** `claude-code/devcontainer-templates/` with ready-made `attended-*.json` and `unattended-*.json` skeletons for fresh projects. `/harden-devcontainer` can offer to copy one in.

### Observability / admin

- **O1. Run log browser.** Small CLI (`agentic/scripts/ralph-runs.sh`) that reads `~/.local/state/ralph/runs/*.jsonl`, prints a table of recent runs with cost, verify pass rate, exit code, elapsed. `--session <id>` to drill into one. `--cost-since 7d` for spend analysis.
- **O2. Stall detection** (deleted task from earlier). Track whether `progress.txt` changes across N iterations AND verify keeps failing -- fire a distinct notification. Circuit breaker already covers the main case but this would differentiate "stuck on same error" from "no progress output".

### Discipline / polish

- **P1. Move `post-dep-audit.sh` to `agentic/hooks/`.** Currently deploys to every Claude Code user even if they don't use agentic. Move and register the hook only during `_setup_agentic`. Small; improves separation.
- **P2. `claude-code` -> `agentic` drift check.** A consistency test that asserts no `claude-code/` file references `agentic/` paths (P1 shouldn't depend on P2) and vice versa for anything that should be self-contained. Extends `tests/test-consistency.sh`.
- **P3. `/context-prime` awareness of agentic/.** Update `claude-code/commands/context-prime.md` (if it's not already) to know about the `agentic/` subtree and surface it appropriately when priming.

### Future / uncommitted

- **F1. Pipeline integration.** A future PR could wire `pipeline.md` to invoke `ralph.sh --phased` for its implement+qa stages. Intentionally out of scope for Tier 2; revisit after 2C lands and the `--phased` shape is proven.
- **F2. Multi-model support in cost tracking.** Per-iteration cost detection currently depends on `claude --output-format json`. If the CLI ever removes that or different models cost differently, we may need a pricing table. Re-evaluate once Anthropic clarifies CLI output stability.

---

## How to pick this up cold

1. Read this file and `agentic/planning/2026-04-19-unattended-stack-maturity.md`.
2. Pick the next work item from Tier 2 (usually 2A).
3. Branch naming: `feat/tier-2-<label>` (e.g., `feat/tier-2-context-phased-estimate`) for Tier 2; `feat/<theme>-<label>` or `chore/<label>` for backlog items.
4. Commit style: conventional commits, no emojis, no AI attribution.
5. No direct pushes to `main`. Open a PR with a detailed body referencing this plan.
6. Verify: `make lint && make test` clean before pushing.
