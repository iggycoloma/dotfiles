# unattended-harness

## Overview

Opt-in harness for running Claude Code autonomously: overnight loops, parallel feature work across worktrees, and hardened devcontainer sandboxes.
Lives under `unattended/` in the repo and deploys to `~/.unattended/` only when `./install.sh --with-unattended` (or `DOTFILES_INSTALL_UNATTENDED=1`) is set.
Three components: `ralph.sh` (autonomous loop), `dc-audit.sh` (devcontainer linter), `.devcontainer/unattended/` (hardened profile with mitmproxy egress allowlist).

Naming note: the broader vocabulary distinguishes "agentic" (the interactive tools -- Claude Code and Codex CLI -- always installed) from "unattended harness" (this opt-in autonomous stack).
The capability was previously called `agentic-harness`; it was renamed to match the repo, deploy path, and install flag.

## Requirements

### Opt-in deployment

- The unattended harness MUST NOT deploy by default.
  The installer MUST deploy `~/.unattended/` only when `DOTFILES_INSTALL_UNATTENDED=1` is set (either via `--with-unattended` flag or directly in env).
- The unattended devcontainer profile MUST set `DOTFILES_INSTALL_UNATTENDED=1` in `containerEnv` so it always installs there.
- `--without-unattended` MUST set `DOTFILES_INSTALL_UNATTENDED=0` (explicit opt-out for CI/scripted contexts).

### Layout under ~/.unattended/

- The deployed `~/.unattended/` MUST contain `scripts/`, `templates/`, `bootstrap/`, `devcontainer-rubric.json`, `egress-allowlist.txt`, `lib/logging.sh` (vendored from `bootstrap/logging.sh`).
- Every script in `scripts/` and `bootstrap/` MUST be executable.

### ralph.sh: autonomous loop

- `ralph.sh` MUST run Claude Code in a loop driven by a PRD file and a per-iteration prompt template.
- Each iteration MUST: orient on `progress.txt`, plan, implement, run a user-supplied verify command, commit if verify passes, record learnings, repeat.
- `ralph.sh` MUST halt on any of: completion (all PRD tasks done), max iterations, total wall-clock exceeded, single iteration timeout, circuit breaker (N consecutive stalls), session budget exceeded, Claude exit error, or safety gate trigger.
- `ralph.sh` MUST exit with documented codes: 0 complete, 1 error/safety, 2 iter limit, 3 wall-clock, 4 iter timeout, 5 circuit breaker, 6 session budget.
- `ralph-parallel.sh` MUST launch N ralph instances on separate git worktrees so multiple features can progress in parallel without branch contention.

### dc-audit.sh: devcontainer linter

- `bin/dc-audit.sh` MUST lint a `devcontainer.json` against rules in `unattended/devcontainer-rubric.json`.
- The rubric MUST contain 20+ rules covering: image/feature pinning (`image-pinned`, `image-required`, `features-pinned`); container lifecycle (`shutdown-action`, `update-remote-user-uid`, `wait-for-declared`); privilege boundary (`no-new-privileges`, `runargs-privileged`, `runargs-cap-sys-admin`, `runargs-seccomp-unconfined`); resource caps (`pids-limit-attended`, `pids-limit-unattended`, `memory-cap-unattended`, `cpu-cap-unattended`, `cap-drop-unattended`); credential and mount hygiene (`no-host-creds-unattended`, `host-creds-mount-attended`, `docker-sock-mount`, `broad-home-mount`); env hygiene (`fixed-env-in-containerenv`).
- dc-audit MUST support `--profile attended` (default) and `--profile unattended` (stricter rules: cap drops, no host credential mounts, resource caps).
- dc-audit MUST support `--fix` (additive fixes only -- never overwrites or removes existing values).
- dc-audit MUST support `--strict --json` for CI usage (non-zero exit on warnings, JSONL output).
- dc-audit MUST work standalone in any repo (not require dotfiles to be fully installed).
- The profile-to-directory mapping (`.devcontainer/unattended/*` -> unattended, every other `.devcontainer/*` -> attended) MUST be exercised by `tests/test-dc-audit.sh`.

### Unattended devcontainer profile

- `.devcontainer/unattended/devcontainer.json` MUST set `runArgs` to include `--cap-drop=ALL`, `--cap-add` minimal capabilities, `--pids-limit=1024`, resource caps, `--security-opt=no-new-privileges`.
- `containerEnv` MUST set `CLAUDE_UNATTENDED=1` and `DOTFILES_INSTALL_UNATTENDED=1`.
- `postCreateCommand` MUST run, in order: `install.sh --with-unattended`, `unattended/bootstrap/unattended-deps.sh`, `unattended/bootstrap/unattended-proxy.sh`.
- The profile MUST NOT mount `~/.ssh`, `~/.config/gh`, or `~/.aws` from the host.
- `GH_TOKEN` MUST be passed per-run via `localEnv.GH_TOKEN_UNATTENDED`, with the recommendation to use a fine-grained single-repo token.

### Egress allowlist (mitmproxy)

- `unattended/egress-allowlist.txt` MUST list every host that mitmproxy permits in the unattended profile.
- `unattended-proxy.sh` MUST install mitmproxy, install its CA in the container's trust store, and start mitmproxy with the allowlist applied.
- Every HTTP/HTTPS request from the container MUST be logged.
- Attended devcontainers MUST NOT enforce egress at the network layer.
  Posture for attended profiles is dc-audit spec-linting (see `docs/sandbox.md`); the prior `bootstrap/devcontainer-egress.sh` iptables approach was removed because the container itself is the trust boundary on hosts the user already trusts.

### Unattended deps

- `unattended-deps.sh` MUST install: pip-audit, cargo-audit, govulncheck, osv-scanner.
- `unattended-entrypoint.sh` MUST validate `GH_TOKEN` scope before ralph starts and MUST fail closed if the token has unexpected scopes.

## Scenarios

### Scenario: Default install does not deploy harness

GIVEN a host without `DOTFILES_INSTALL_UNATTENDED` set
WHEN `./install.sh` runs without `--with-unattended`
THEN `~/.unattended/` is not created
AND the installer logs `Unattended Harness: disabled (pass --with-unattended to opt in)`.

### Scenario: --with-unattended deploys the harness

GIVEN a host install
WHEN the user runs `./install.sh --with-unattended`
THEN `~/.unattended/scripts/ralph.sh` is deployed and executable
AND `~/.unattended/devcontainer-rubric.json` is deployed
AND `~/.unattended/lib/logging.sh` is vendored from `bootstrap/logging.sh`
AND the installer logs `Unattended coding harness deployed to ~/.unattended/`.

### Scenario: ralph circuit breaker halts on stalls

GIVEN ralph is running with a 3-stall circuit-breaker threshold
AND three consecutive iterations produce no commit and no progress.txt update
WHEN the fourth iteration begins
THEN ralph halts with exit code 5
AND logs `Circuit breaker: 3 consecutive stalls`.

### Scenario: dc-audit catches a missing security flag

GIVEN `.devcontainer/foo/devcontainer.json` lacks `--security-opt=no-new-privileges`
WHEN the user runs `bin/dc-audit.sh --profile unattended .devcontainer/foo/devcontainer.json`
THEN the audit reports `WARN: missing --security-opt=no-new-privileges`
AND exits non-zero (with `--strict`).

### Scenario: Unattended profile blocks egress to unlisted host

GIVEN the unattended devcontainer is up with mitmproxy running
AND `unattended/egress-allowlist.txt` does not include `evil.example.com`
WHEN code in the container attempts `curl https://evil.example.com/`
THEN mitmproxy blocks the request
AND logs the blocked attempt
AND `curl` exits with a connection error.

## Non-Behavior

- The harness does NOT deploy by default; opt-in is required.
- ralph does NOT auto-merge or auto-push; it only commits to the local branch.
- ralph does NOT continue past safety gates triggered by Claude Code's hooks (pre-security blocks, etc.).
- dc-audit does NOT remove or overwrite existing `runArgs` entries (additive only).
- The unattended profile does NOT trust any host TLS cert beyond mitmproxy's CA.
- The unattended profile does NOT mount host credentials (no `~/.ssh`, no `~/.config/gh`, no `~/.aws`).
- The harness does NOT yet share context across parallel ralph loops (called out as a current gap in `unattended/planning/`).
- Attended profiles do NOT enforce network egress; the prior iptables allowlist was removed in favor of dc-audit spec-linting (the container is the boundary).
