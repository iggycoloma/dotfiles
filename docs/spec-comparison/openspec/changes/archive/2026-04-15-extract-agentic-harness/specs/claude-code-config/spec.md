# claude-code-config -- Change Delta (extract-agentic-harness, ARCHIVED)

> Removes the agentic-payload requirements from `claude-code-config`
> (they move to `agentic-harness` -- see the sibling delta in this
> change folder). Also removes the transitional back-compat symlinks
> that PR #46 introduced; PR #47 took them out.

## ADDED Requirements

(none -- this delta only modifies and removes from the existing `claude-code-config` spec.)

## MODIFIED Requirements

### `_setup_claude_code` deployment surface

**Previous behavior**: The installer deployed the following from `claude-code/` to `~/.claude/`:

- `settings.json`, `CLAUDE.md`, `statusline.sh`
- `hooks/`, `agents/`, `commands/`
- `templates/` (PRD.md, PROMPT.md, progress.txt)
- `scripts/` (ralph.sh and friends)
- `devcontainer-rubric.json`, `egress-allowlist.txt`
- `bootstrap/` (unattended-deps.sh, etc.)

**New behavior**: The installer deploys ONLY:

- `settings.json`, `CLAUDE.md`, `statusline.sh`
- `hooks/`, `agents/`, `commands/`

The remaining items (templates, scripts, rubric, allowlist, bootstrap) are owned by the new `agentic-harness` capability and deployed under `~/.agentic/` only when opted in.

## REMOVED Requirements

### Agentic payload in claude-code

**Removed**: The previous spec required the installer to deploy the following to `~/.claude/`:

- `~/.claude/templates/` (PRD.md, PROMPT.md, progress.txt)
- `~/.claude/scripts/` (ralph.sh, ralph-parallel.sh, ralph-spec.sh)
- `~/.claude/devcontainer-rubric.json`
- `~/.claude/egress-allowlist.txt`
- `~/.claude/bootstrap/` (unattended-deps.sh, unattended-proxy.sh, unattended-entrypoint.sh)

**Why removed**: These belong to the agentic harness (P2), not the personal Claude Code config (P1).
They are now deployed under `~/.agentic/` only when `DOTFILES_INSTALL_AGENTIC=1`.

**Migration**: Operators with scripts referencing the old paths (`~/.claude/scripts/ralph.sh`, etc.) MUST update to the new paths (`~/.agentic/scripts/ralph.sh`).

### Transitional back-compat symlinks (added then removed within
this change)

**Briefly required (PR #46)**: To soften the path break, PR #46 required the installer to create transitional symlinks when both `~/.agentic/` and `~/.claude/` existed:

- `~/.claude/scripts -> ~/.agentic/scripts`
- `~/.claude/templates -> ~/.agentic/templates`
- `~/.claude/devcontainer-rubric.json -> ~/.agentic/devcontainer-rubric.json`

**Removed in PR #47**: The symlinks were removed once a release had passed for callers to migrate.
The current spec does NOT require back-compat symlinks.
Any operator still using the old paths must have updated their callers by now.

**Migration window**: PR #46 (2026-04-15) -> PR #47 (2026-04-22) = one week.
In retrospect this was tight; future path migrations should allow at least one full release cycle.

### Legacy rubric path lookups in dc-audit

**Removed**: PR #46 had `bin/dc-audit.sh` look for the rubric in several legacy paths (`~/.claude/devcontainer-rubric.json`, `./claude-code/devcontainer-rubric.json`) before falling back to the new locations.

**Removed in PR #47**: Now `bin/dc-audit.sh` looks only in:

1. `agentic/devcontainer-rubric.json` (in-repo)
2. `~/.agentic/devcontainer-rubric.json` (deployed)

If neither exists, dc-audit exits with a clear error pointing at the two valid locations.

---

## Notes for the reviewer

This delta exercises every part of OpenSpec's delta vocabulary in a single change folder:

- `## ADDED Requirements` -- empty here (the additions live in the sibling `install` and `agentic-harness` deltas).
- `## MODIFIED Requirements` -- one entry: the deployment surface of `_setup_claude_code` shrunk.
- `## REMOVED Requirements` -- two entries: the agentic payload that moved out, AND the transitional back-compat symlinks that briefly existed and were then removed within this same change.

The "added then removed within one change" pattern is unusual but authentic to how PRs #46 and #47 played out.
OpenSpec's archive model captures both states cleanly: at archive time, the canonical spec absorbs the *final* state (no back-compat symlinks), and the historical state is preserved in this archived folder.
