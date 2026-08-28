# Extract Agentic Harness -- Proposal (ARCHIVED)

> **Archived 2026-04-22** -- merged via PRs #46 (extraction, opt-in) and
> #47 (back-compat symlink removal). Kept here as the audit trail.

## Intent

The agentic harness components (ralph autonomous loop runner, templates, dc-audit rubric, unattended devcontainer profile, mitmproxy egress allowlist) had grown to live alongside personal Claude Code config under `claude-code/`.
This conflated two distinct products:

1. **P1 (Dotfiles / terminal QoL)** -- shell config, git config, personal Claude Code config.
   What every developer wants on every machine.
2. **P2 (Agentic harness)** -- autonomous loop runner, hardened sandboxes.
   What developers want only when running Claude Code without human review.

Mainstream developers installing the dotfiles were silently getting ralph.sh, the dc-audit rubric, templates, and unattended bootstrap scripts deployed into their `~/.claude/` -- all of which they would never use.
The blast surface for autonomous-Claude tooling was default-on for every install.

This change separates the two products.
The agentic harness moves to a dedicated `agentic/` subtree and deploys to `~/.agentic/` only when the user explicitly opts in.

## Scope

### In scope

- New `agentic/` subdirectory at the repo root containing:
  - `scripts/` (ralph.sh, ralph-parallel.sh, ralph-spec.sh)
  - `templates/` (PRD.md, PROMPT.md, progress.txt)
  - `bootstrap/` (unattended-deps.sh, unattended-proxy.sh, unattended-entrypoint.sh)
  - `devcontainer-rubric.json`, `egress-allowlist.txt`, README.md
- New `bin/dc-audit.sh` at the repo root (standalone-runnable; consumes the rubric).
- `--with-agentic` / `--without-agentic` flags on `install.sh`.
- `DOTFILES_INSTALL_AGENTIC=1` env var as the underlying toggle.
- New `_setup_agentic` helper in `bootstrap/symlinks.sh` deploying `~/.agentic/`.
- Vendored `bootstrap/logging.sh` -> `~/.agentic/lib/logging.sh` so ralph runs without the dotfiles repo present.
- Unattended devcontainer profile at `.devcontainer/unattended/` with `containerEnv: { DOTFILES_INSTALL_AGENTIC: "1" }` so the unattended context auto-deploys the harness.

### Out of scope

- The transitional back-compat symlinks (e.g.
  `claude-code/scripts -> agentic/scripts`) -- these are removed in a follow-up change (`remove-agentic-back-compat-symlinks`) once we confirm no caller in the wild depends on the old paths.
- Changes to ralph or dc-audit behavior.
  This is a relocation / packaging change only.
- Tier 2 work (cross-loop context, phased iteration, estimate) --separate proposal.

## Approach

1. Move every agentic file from its current location to `agentic/`.
   Preserve git history with `git mv`.
2. Add `_setup_agentic` to `bootstrap/symlinks.sh` gated on `DOTFILES_INSTALL_AGENTIC=1`.
3. Add `--with-agentic` flag to `install.sh` setting the env var.
4. Update `_setup_claude_code` to no longer deploy the agentic payload (templates, scripts, rubric) -- it stops touching them entirely.
5. Add `bin/dc-audit.sh` standalone tool reading the rubric from `agentic/devcontainer-rubric.json` (when run from a checkout) or `~/.agentic/devcontainer-rubric.json` (when the harness is deployed).
6. Add the unattended devcontainer profile setting `DOTFILES_INSTALL_AGENTIC=1` in `containerEnv`.
7. Vendor `bootstrap/logging.sh` to `~/.agentic/lib/` so ralph can `source ~/.agentic/lib/logging.sh` without `DOTFILES_DIR`.
8. Update README.md to introduce the "two products in this repo" model.
9. **Follow-up PR** (#47): remove the transitional back-compat symlinks now that callers have had a release to migrate.

## Impact

### Positive

- Mainstream installs are smaller: no `~/.claude/scripts/`, `~/.claude/templates/`, no rubric, no unattended bootstrap scripts.
- Autonomous-Claude tooling is opt-in; default-off.
- Audit and review of changes is easier -- agentic concerns isolated in one subdirectory.

### Negative

- Operators who scripted against the old paths (`~/.claude/scripts/ralph.sh`) need to update their callers to `~/.agentic/scripts/ralph.sh`.
  Mitigated by the transitional back-compat symlinks shipped in PR #46 and removed only in PR #47.
- The unattended devcontainer profile must explicitly set `DOTFILES_INSTALL_AGENTIC=1` -- one extra line in `devcontainer.json`.
  Acceptable.

## Acceptance Criteria

- `./install.sh` (no flags) produces a host where `~/.agentic/` does not exist.
- `./install.sh --with-agentic` produces a host where `~/.agentic/scripts/ralph.sh` is executable.
- `_setup_claude_code` no longer references templates/scripts/rubric.
- `bin/dc-audit.sh` works in any repo (dotfiles installed or not), consuming the rubric from either `agentic/devcontainer-rubric.json` (in-repo) or `~/.agentic/devcontainer-rubric.json` (deployed).
- The unattended devcontainer profile auto-installs the harness via `containerEnv: { DOTFILES_INSTALL_AGENTIC: "1" }`.
- `make test` is green on every matrix cell after the move.
- README.md "Two products" section explains the boundary.
