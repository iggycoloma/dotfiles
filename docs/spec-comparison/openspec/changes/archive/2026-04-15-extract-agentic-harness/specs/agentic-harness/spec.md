# agentic-harness -- Change Delta (extract-agentic-harness, ARCHIVED)

> This delta INTRODUCED the `agentic-harness` capability as a
> standalone spec. Before this change, the capability did not exist
> as a separate concept -- its components were entangled with
> `claude-code-config`.

## ADDED Requirements

### Capability existence

- The repo MUST have a top-level `agentic/` directory containing the autonomous-Claude tooling, separate from the personal Claude Code config.
- The capability MUST be opt-in.
  Mainstream installs MUST NOT deploy `~/.agentic/`.

### Opt-in flags

- `install.sh` MUST accept `--with-agentic` setting `DOTFILES_INSTALL_AGENTIC=1`.
- `install.sh` MUST accept `--without-agentic` setting `DOTFILES_INSTALL_AGENTIC=0` (explicit opt-out).
- The unattended devcontainer profile MUST set `DOTFILES_INSTALL_AGENTIC=1` in `containerEnv` so it auto-deploys.

### `~/.agentic/` deployment

- When opted in, the installer MUST deploy `~/.agentic/` containing:
  - `scripts/` (ralph.sh, ralph-parallel.sh, ralph-spec.sh)
  - `templates/` (PRD.md, PROMPT.md, progress.txt)
  - `bootstrap/` (unattended-deps.sh, unattended-proxy.sh, unattended-entrypoint.sh)
  - `devcontainer-rubric.json`, `egress-allowlist.txt`, README.md
  - `lib/logging.sh` (vendored from `bootstrap/logging.sh`)
- All scripts in `scripts/` and `bootstrap/` MUST be executable.

### dc-audit standalone tool

- `bin/dc-audit.sh` MUST exist at the repo root.
- `bin/dc-audit.sh` MUST work in any repo (does not require `~/.agentic/` to be deployed; reads rubric from `agentic/devcontainer-rubric.json` in-repo or `~/.agentic/devcontainer-rubric.json` deployed).
- `bin/dc-audit.sh` MUST support `--profile attended | unattended`, `--fix` (additive only), `--strict --json` (CI mode).

### Unattended devcontainer profile

- `.devcontainer/unattended/devcontainer.json` MUST exist with:
  - `runArgs` including `--cap-drop=ALL`, `--security-opt=no-new-privileges`, `--pids-limit=1024`, resource caps.
  - `containerEnv` setting `CLAUDE_UNATTENDED=1` and `DOTFILES_INSTALL_AGENTIC=1`.
  - `postCreateCommand` running `install.sh --with-agentic` -> `agentic/bootstrap/unattended-deps.sh` -> `agentic/bootstrap/unattended-proxy.sh`.
  - No mounts of `~/.ssh`, `~/.config/gh`, `~/.aws` from host.
  - GH_TOKEN from `localEnv.GH_TOKEN_UNATTENDED`.

### ralph safety gates

- ralph.sh MUST halt with documented exit codes on each of seven safety conditions (completion, max iters, wall clock, iter timeout, circuit breaker, session budget, Claude/safety error).

## MODIFIED Requirements

(none -- this delta CREATED the capability; nothing pre-existing to modify within `agentic-harness` scope.
See the `install` and `claude-code-config` deltas in this same change folder for the modifications elsewhere.)

## REMOVED Requirements

(none -- this delta is purely additive within `agentic-harness`.)
