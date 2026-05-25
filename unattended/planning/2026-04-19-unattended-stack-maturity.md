# Unattended Agentic Coding: Stack Maturity and Next Phase

## Context

This document tracks the maturity of the dotfiles repo's unattended Claude Code
workflow (ralph.sh) against the 8-layer agentic coding stack described in the
community consensus (early 2026). It serves as the execution plan for the next
phase of hardening.

Completed work lives on `feat/unattended-hardening` (PR #43).

## Layer Maturity

| # | Layer | Score | Reasoning |
|---|-------|-------|-----------|
| 1 | **Spec** | 60% | PRD.md template has checklist-based acceptance criteria (`- [ ]`), in-scope/out-of-scope sections, and per-task "done when" criteria. But criteria are freeform prose -- not machine-verifiable. No JSON schema, no spec versioning, no commit-hash linkage to the PRD revision an iteration works from. |
| 2 | **Loop / Execution** | 75% | ralph.sh is a mature bash loop with iteration cap, wall-clock, budget, and timeout. PROMPT.md now enforces 6 explicit phases per iteration (Orient, Plan, Implement, Verify, Commit, Record) -- plan-before-code prevents blind dives. However, ralph itself is still a single-mode blob; it does not support phased multi-pass runs (e.g., plan-only pass then implement pass). The pipeline command + 4 subagents exist but are not wired into ralph. |
| 3 | **Context Management** | 50% | progress.txt carries completed tasks, current task, blockers, and a Learnings section for cross-iteration knowledge transfer. Session-id persistence means Claude keeps conversation context across iterations. But there is no AGENTS.md discovery file that accumulates project-specific learnings (e.g., "useCallback requires useMemo here"), no git-tag-per-task for artifact linking, and ralph-parallel.sh spawns N independent loops with zero shared context. |
| 4 | **Verification** | 80% | `--verify-cmd` runs after each Claude iteration and gates the `## COMPLETE` sentinel -- if verify fails, the sentinel is stripped and the loop continues. PROMPT.md mandates revert-on-red (attempt one fix; if still failing, `git checkout -- .` and document the blocker). pre-commit-validate.sh enforces conventional commits on all agent commits. Missing: no automated coverage threshold enforcement, no browser/UI verification for frontend work, no CI gate embedded in the loop. |
| 5 | **Sandbox** | 50% | settings.json deny list covers Read/Write/Edit for 40+ credential patterns plus 36 Bash deny patterns for destructive ops. pre-security.sh hook scans Bash commands for credential paths. post-scope-audit.sh logs writes outside the project scope. Permission mode defaults to `plan`; `acceptEdits` requires explicit `--yolo`. But: no devcontainer "unattended" profile with resource caps, no network egress control (curl is blanket-allowed), no iptables/proxy, ralph will happily run on a developer laptop with full filesystem. |
| 6 | **Guardrails** | 90% | Iteration cap (default 20, capped at 50 under RALPH_MAX_MODE). Per-iteration budget ($10 default). Per-iteration timeout (900s via `timeout --kill-after=10`). Total wall-clock (4h). Circuit breaker halts after 3 consecutive iterations with no progress.txt change (exit 5). Git checkpoint commits after every iteration. `--bare` + `acceptEdits` emits loud warning. RALPH_MAX_MODE requires RALPH_UNSAFE_MODE to exceed 50 iterations. Missing: no cumulative cost tracking across iterations, no per-session dollar cap (only per-iteration). |
| 7 | **Observability** | 45% | Pushover notifications on complete, timeout, error, wall-clock, max-iterations, stuck. Structured log calls via bootstrap/logging.sh. Git checkpoint commits provide a per-iteration audit trail. Session-id printed at start. But: no cost tracking at all (ralph builds the --max-budget-usd flag but never captures actual spend), no structured JSONL run log, no per-task timing/token breakdown, no "50% of budget spent" warning, no dashboard or post-run summary. |
| 8 | **Task Selection** | 20% | PRD template provides structure but no validation. No guidance on ideal PRD size or task granularity. No complexity estimator. No spec version pinning (if PROMPT.md or PRD changes mid-run, old iterations can't be audited). ralph-parallel.sh requires manual branch:prd-file pairing. No example specs directory in the repo. |

**Overall: ~59%** (up from ~45% before this PR).

## What Shipped (PR #43)

### Commit 1: `feat: add ralph autonomous loop harness`
- ralph.sh, ralph-parallel.sh, PRD/PROMPT/progress templates
- ccw/ccwls/ccwclean shell helpers, test-ralph.sh suite
- Planning docs, Makefile integration

### Commit 2: `feat(claude-code): harden defaults for unattended agent runs`
- settings.json: Write/Edit credential denies + 36 Bash destructive-op denies
- ralph.sh: default permission mode `plan`, `--yolo`/`RALPH_UNSAFE_MODE` gate, `--iteration-timeout`, `--max-wall-clock`, RALPH_MAX_MODE iteration cap, `--bare`+`acceptEdits` warning
- post-scope-audit.sh PostToolUse hook (logs out-of-scope writes)
- session-start-banner.sh with CLAUDE_UNATTENDED=1 branch
- TRIGGER/SKIP clauses on security-audit, debug, review-pr, fix-issue skills

### Commit 3: `feat(ralph): add verification gating, git checkpoint, and circuit breaker`
- `--verify-cmd` gates `## COMPLETE` (strips sentinel if verify fails)
- Automatic git checkpoint per iteration (`--no-checkpoint` to disable)
- Circuit breaker: halt after N stalls (default 3, `--circuit-breaker N`, exit code 5)
- Phase-separated PROMPT.md (Orient/Plan/Implement/Verify/Commit/Record)
- Learnings section in progress.txt
- 17 new tests (66 total in ralph suite)

### Exit code table (ralph.sh)
| Code | Meaning |
|------|---------|
| 0 | All tasks complete, verify passed |
| 1 | Claude exited with error |
| 2 | Max iterations reached |
| 3 | Total wall-clock exceeded |
| 4 | Single iteration timed out |
| 5 | Circuit breaker (N stalls) |

## Next Phase: Execution Plan

### Tier 1 -- High ROI, independent of each other

#### 1A. Devcontainer "unattended" profile (Sandbox layer: 50% -> 85%)

Create `.devcontainer/unattended/devcontainer.json`:
- `--cap-drop=ALL` + minimal capability adds
- `--pids-limit=1024`, `--memory=8g`, `--cpus=4`
- `containerEnv` (not `remoteEnv`) for `CLAUDE_UNATTENDED=1`, `RALPH_DEFAULT_BUDGET=5`
- Workspace-only mounts (no ~/.ssh, ~/.aws, ~/.config/gh from host)
- GH_TOKEN passed per-run via env, not baked in; fine-grained token scoped to one repo

Network egress via container-local mitmproxy:
- Allowlist: api.anthropic.com, github.com hosts, npm/pypi/cargo registries, api.pushover.net
- Full request logging to `~/.local/state/ralph/runs/<timestamp>/egress.mitm`
- iptables belt-and-suspenders if NET_ADMIN available (force traffic through proxy)
- `bootstrap/unattended-proxy.sh` sets up the proxy at postCreateCommand

Dependency audit hook:
- PostToolUse `post-dep-audit.sh` fires on npm/pip/cargo/go install commands
- Runs the matching audit tool; fails the tool call if audit binary missing
- `bootstrap/unattended-deps.sh` installs npm-audit, pip-audit, cargo-audit, govulncheck, osv-scanner

Files: `.devcontainer/unattended/devcontainer.json`, `bootstrap/unattended-proxy.sh`,
`bootstrap/unattended-deps.sh`, `bootstrap/unattended-entrypoint.sh`,
`claude-code/unattended/egress-allowlist.txt`, `claude-code/hooks/post-dep-audit.sh`

#### 1B. Structured spec with machine-verifiable acceptance criteria (Spec layer: 60% -> 85%)

Redesign PRD.md template:
- Each task gets a structured block with `id`, `description`, `verify` (shell command
  that returns 0 when the criterion is met), and `done: false`
- ralph.sh gains `--spec-file` that reads the structured spec and passes per-task
  verify commands to `--verify-cmd` automatically
- Spec version: sha256 of the PRD is recorded in progress.txt header; if PRD changes
  mid-run, ralph logs a warning

Format (YAML frontmatter + markdown body):
```yaml
spec_version: 1
tasks:
  - id: add-auth-middleware
    description: Add JWT auth middleware to /api routes
    verify: "make test && grep -q 'auth_middleware' src/middleware/index.ts"
    done: false
  - id: add-rate-limiter
    description: Add rate limiting to public endpoints
    verify: "make test && curl -s localhost:3000/health | jq -e '.rateLimit'"
    done: false
```

Files: `claude-code/templates/PRD.md` (rewrite), `claude-code/scripts/ralph.sh` (add
`--spec-file` parsing)

#### 1C. Structured run log and cost tracking (Observability layer: 45% -> 75%)

After each iteration, append a JSONL record to `~/.local/state/ralph/runs/<session-id>.jsonl`:
```json
{"iteration":3,"timestamp":"2026-04-19T03:12:00Z","exit_code":0,"verify_passed":true,"progress_hash":"abc123","elapsed_s":147,"checkpoint_sha":"def456"}
```

If Claude CLI supports `--output-format json` (check at runtime), parse the response for
token counts and cost. Otherwise log `"cost":null` and defer to API billing.

Add `--session-budget <dollars>` that sums per-iteration cost from the JSONL and halts
when exceeded. Independent of `--max-budget-usd` (which is per-invocation).

Post-run summary: when the loop exits (any code), print a table:
```
Ralph run summary (session abc12345):
  Iterations: 7/20
  Wall-clock: 1842s (30m 42s)
  Verify:     6 passed, 1 failed
  Checkpoint: 6 commits
  Exit:       0 (complete)
```

Files: `claude-code/scripts/ralph.sh` (JSONL writer, summary printer, `--session-budget`)

### Tier 2 -- Lower urgency, builds on Tier 1

#### 2A. Task selection guidance and complexity estimation (Task Selection: 20% -> 50%)

- Add a `claude-code/commands/estimate.md` skill that analyzes a PRD and returns:
  estimated iterations, estimated cost, risk factors, recommended `--max-iterations`
- Add example specs in `claude-code/templates/examples/` (migration, bugfix, greenfield)
- Document ideal PRD size (5-15 tasks, each completable in one iteration)

#### 2B. Cross-iteration context sharing for parallel runs (Context: 50% -> 70%)

- ralph-parallel.sh writes a shared `discoveries.md` that each loop reads at iteration start
- Each loop appends learnings from its domain (e.g., "API rate limit is 100/min")
- Use `flock` for concurrent-safe appends

#### 2C. Ralph-pipeline integration (Loop/Execution: 75% -> 90%)

- Add `--phased` mode to ralph.sh that runs three sequential passes:
  1. Plan pass: Claude reads PRD, writes a detailed implementation plan, commits it
  2. Implement pass: Claude iterates on the plan, one task per iteration
  3. Review pass: Claude runs the qa-reviewer agent, documents findings
- Each pass is a separate ralph loop with a different PROMPT.md
- Pipeline command could dispatch this instead of the manual 4-agent dance

#### 2D. Harden existing devcontainer profiles (Sandbox: lightly)

- Add `--pids-limit=2048` and `--security-opt=no-new-privileges` to ubuntu-zsh and debian-bash
- No credential-mount changes for attended profiles

## Verification Criteria for Next Phase

- `make lint && make test` pass
- Devcontainer "unattended" builds and starts (`devcontainer up --workspace-folder .`)
- mitmproxy blocks a request to a non-allowlisted host
- `--verify-cmd "false"` prevents `## COMPLETE` from sticking (already tested)
- `--spec-file` reads YAML tasks and wires verify commands
- JSONL log written after each iteration; `--session-budget` halts on overspend
- Parallel runs with shared `discoveries.md` don't corrupt each other under `flock`
