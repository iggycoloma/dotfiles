# Agentic Harness

Tooling for running Claude Code autonomously -- overnight loops, parallel feature work across worktrees, and hardened devcontainer sandboxes. This subtree is opt-in; pass `--with-agentic` to `install.sh` (or set `DOTFILES_INSTALL_AGENTIC=1`) to deploy it to `~/.agentic/`.

This is a separate product from the rest of the repo. The root `install.sh` is for terminal quality-of-life on any machine the user wants a consistent developer environment on. Everything here only matters when you are running Claude Code without a human reviewing every step.

## Layout

```
agentic/
|-- README.md                       (this file)
|-- scripts/
|   |-- ralph.sh                    Autonomous loop runner
|   |-- ralph-parallel.sh           Launch N loops on separate worktrees
|   |-- ralph-spec.sh               Sourced helper: YAML frontmatter parsing
|-- templates/
|   |-- PRD.md                      Feature spec with optional YAML task list
|   |-- PROMPT.md                   Per-iteration phased prompt
|   |-- progress.txt                Progress tracking + learnings log
|-- bootstrap/
|   |-- unattended-deps.sh          Installs pip-audit, cargo-audit, govulncheck, osv-scanner
|   |-- unattended-proxy.sh         mitmproxy + egress allowlist + CA trust
|   |-- unattended-entrypoint.sh    Validates GH_TOKEN scope before ralph starts
|-- devcontainer-rubric.json        Rules consumed by bin/dc-audit.sh
|-- egress-allowlist.txt            Hosts mitmproxy permits in the unattended profile
|-- planning/                       Design notes and next-phase plans
```

CLI tools live in the repo's top-level `bin/`:

- `bin/dc-audit.sh` -- lints `devcontainer.json` files against the rubric here. See the root README for usage.

## The three main entry points

### 1. `ralph.sh` -- run Claude Code in a loop

```bash
ralph.sh --prompt-file agentic/templates/PROMPT.md --prd PRD.md \
    --spec-file PRD.md \
    --verify-cmd "make test" \
    --session-budget 5 \
    --max-wall-clock 14400
```

Each iteration: orients on `progress.txt`, plans, implements, runs verify, commits (if green), records learnings. Halts on completion, iteration limit, wall-clock, per-iteration timeout, circuit breaker (N consecutive stalls), session budget, or error.

Exit codes:

| Code | Meaning |
| --- | --- |
| 0 | All tasks complete, verify passed |
| 1 | Claude exited with error or safety gate triggered |
| 2 | Max iterations reached |
| 3 | Total wall-clock exceeded |
| 4 | Single iteration timed out |
| 5 | Circuit breaker (N stalls) |
| 6 | Session budget exceeded |

### 2. `dc-audit.sh` -- lint `devcontainer.json`

```bash
bin/dc-audit.sh --profile unattended .devcontainer/ci/devcontainer.json
bin/dc-audit.sh --fix .devcontainer/*/devcontainer.json
bin/dc-audit.sh --strict --json            # CI-friendly
```

Rules (see `devcontainer-rubric.json`): image/feature pinning, `--security-opt=no-new-privileges`, resource caps, forbidden host credential mounts (unattended), `shutdownAction`, `updateRemoteUserUID`, `waitFor` declaration. Fixes are additive only -- never overwrites or removes existing values.

### 3. `.devcontainer/unattended/` -- the hardened profile

```bash
# From the host:
devcontainer up --workspace-folder . --config .devcontainer/unattended/devcontainer.json
```

What this profile does:

- `--cap-drop=ALL` + minimal adds + `--pids-limit=1024` + resource caps + `--security-opt=no-new-privileges`
- `containerEnv` sets `CLAUDE_UNATTENDED=1` and `DOTFILES_INSTALL_AGENTIC=1`
- `postCreateCommand` runs `install.sh --with-agentic`, then `agentic/bootstrap/unattended-deps.sh`, then `agentic/bootstrap/unattended-proxy.sh`
- No `~/.ssh`, `~/.config/gh`, or `~/.aws` mounted from host
- mitmproxy runs on the container with an allowlist at `agentic/egress-allowlist.txt`; every request is logged
- `GH_TOKEN` passed per-run via `localEnv.GH_TOKEN_UNATTENDED` (prefer a fine-grained single-repo token)

## Stack maturity

Tracked in `planning/2026-04-19-unattended-stack-maturity.md`. Current scores (approximate):

- Spec: 85%
- Loop / Execution: 75%
- Context: 50%
- Verification: 95%
- Sandbox: 85%
- Guardrails: 90%
- Observability: 75%
- Task Selection: 20%

Overall ~72%. The main remaining gaps are context sharing across parallel loops and task-selection guidance.

## Opting in

- **Per-install**: `./install.sh --with-agentic` or `DOTFILES_INSTALL_AGENTIC=1 ./install.sh`
- **Per-devcontainer**: add `DOTFILES_INSTALL_AGENTIC=1` to `containerEnv` in any profile that should deploy the harness
- **Opt out**: `./install.sh --without-agentic` (explicit) or just omit the flag

When deployed, the harness lives at `~/.agentic/`. Back-compat symlinks are created at `~/.claude/scripts/`, `~/.claude/templates/`, and `~/.claude/devcontainer-rubric.json` so pre-reorg references keep working for one release cycle.
