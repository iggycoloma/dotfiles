# Extract Agentic Harness -- Design (ARCHIVED)

## Overview

Move the autonomous-Claude tooling out of `claude-code/` (where it shipped to every install) into a new top-level `agentic/` subtree that deploys to `~/.agentic/` only when `DOTFILES_INSTALL_AGENTIC=1`.
Keep dc-audit at the repo root (`bin/`) so it remains usable in any project.
Wire the unattended devcontainer profile to auto-opt-in via `containerEnv`.

## Architecture

### Before (entangled)

```
claude-code/
|-- CLAUDE.md, settings.json, statusline.sh
|-- hooks/, agents/, commands/        # personal Claude config
|-- scripts/ralph*.sh                 # autonomous loop runner (P2)
|-- templates/{PRD,PROMPT,progress}.md  # P2 templates
|-- devcontainer-rubric.json          # P2 lint rubric
|-- egress-allowlist.txt              # P2 mitmproxy config
+-- bootstrap/                        # P2 unattended bootstrap
.devcontainer/
+-- (only the example/ profile)
bin/
+-- gh-repo-policy.sh
```

`_setup_claude_code` deployed all of the above to `~/.claude/`.
Mainstream installs got the autonomous loop runner and rubric without asking for them.

### After (separated)

```
claude-code/
|-- CLAUDE.md, settings.json, statusline.sh
+-- hooks/, agents/, commands/        # personal Claude config only
agentic/                              # NEW: P2 home
|-- README.md
|-- scripts/ralph.sh, ralph-parallel.sh, ralph-spec.sh
|-- templates/PRD.md, PROMPT.md, progress.txt
|-- bootstrap/unattended-deps.sh, unattended-proxy.sh, unattended-entrypoint.sh
|-- devcontainer-rubric.json
+-- egress-allowlist.txt
.devcontainer/
|-- example/
+-- unattended/                       # NEW: hardened P2 profile
bin/
|-- dc-audit.sh                       # NEW: standalone lint tool
+-- gh-repo-policy.sh
```

`_setup_claude_code` no longer touches scripts/templates/rubric/ bootstrap.
New `_setup_agentic` deploys `~/.agentic/` only when `DOTFILES_INSTALL_AGENTIC=1`.

## Key Decisions

### Decision 1: New `agentic/` subdirectory at repo root

**Chosen**: Top-level `agentic/` (not `claude-code/agentic/` or `scripts/agentic/`).

**Reason**: agentic isn't a sub-product of Claude Code config; it's a parallel product with its own threat model.
Nesting it under `claude-code/` would obscure that.
Putting it at top-level signals "this is a separate concern."

**Trade-off**: One more top-level directory.
Acceptable.

**Rejected**:
- `claude-code/agentic/` -- keeps it nested, suggests it's part of the Claude Code config.
  Wrong story.
- `scripts/agentic/` -- generic; doesn't match the intent (this isn't scripts; it's a deployable subsystem).

### Decision 2: dc-audit lives in `bin/`, not `agentic/`

**Chosen**: `bin/dc-audit.sh` at repo root, alongside other standalone tools (`gh-repo-policy.sh`).

**Reason**: dc-audit is useful for any developer auditing any devcontainer.json -- not just developers running ralph.
Forcing `--with-agentic` to use dc-audit would be an unjustified tax.

**Trade-off**: dc-audit and the rubric live in different directories (`bin/` vs `agentic/`).
Documented in dc-audit's `--help` and in `agentic/README.md`.

**Rejected**: putting dc-audit under `agentic/` -- gates a low-risk linter behind a high-risk opt-in.

### Decision 3: Vendor logging.sh into `~/.agentic/lib/`

**Chosen**: `cp -f bootstrap/logging.sh ~/.agentic/lib/logging.sh` during `_setup_agentic`.

**Reason**: ralph.sh sources `logging.sh` for `log_section` / `log_info` etc. Without vendoring, ralph would need `DOTFILES_DIR` in its environment to find the file.
That's brittle (operators who clone the repo elsewhere break ralph) and couples the deployed harness to the dotfiles checkout.

**Trade-off**: Two copies of `logging.sh` (one in repo, one vendored).
When `logging.sh` changes, the next `install.sh` re-vendors.

**Rejected**: making logging.sh self-contained as a single file ralph copies in -- works but duplicates the file at vendor time.

### Decision 4: Unattended profile sets DOTFILES_INSTALL_AGENTIC=1 in containerEnv

**Chosen**: The unattended devcontainer profile bakes in the opt-in via `containerEnv`.

**Reason**: The unattended profile exists *to run* the harness.
Forcing operators to also pass `--with-agentic` to `install.sh` (invoked by `postCreateCommand`) is redundant.
The profile expresses its intent via env.

**Trade-off**: The opt-in is implicit when using the unattended profile -- operator must read the profile to see the env var.
Acceptable; the profile itself is opt-in.

**Rejected**: requiring `--with-agentic` in `postCreateCommand` --extra duplicated configuration.

### Decision 5: Transitional back-compat symlinks (PR #46), removed in PR #47

**Chosen**: PR #46 ships back-compat symlinks (`~/.claude/scripts -> ~/.agentic/scripts`, etc.) so callers using old paths don't break immediately.
PR #47 removes those symlinks once the deprecation window passes.

**Reason**: The path change is breaking for anyone with scripts that reference `~/.claude/scripts/ralph.sh`.
Two-PR migration gives users a release to update.

**Trade-off**: Two PRs instead of one.
The first PR (#46) deploys state we know we want to remove (the symlinks).
PR #47 cleans up.

**Rejected**: One-shot rename in #46 -- breaks every existing caller without warning.

## Implementation Strategy

### Phase 1: New layout (PR #46)

1. `git mv claude-code/scripts agentic/scripts` (preserves history).
2. Same for `claude-code/templates`, `claude-code/devcontainer-rubric.json`, `claude-code/egress-allowlist.txt`, `claude-code/bootstrap`.
3. Create `agentic/README.md` introducing the harness.
4. Create `bin/dc-audit.sh` (extracted from `claude-code/scripts/devcontainer-audit.sh` if one existed; else new).
5. Add `_setup_agentic` to `bootstrap/symlinks.sh`.
6. Add `--with-agentic`/`--without-agentic` to `install.sh`.
7. Modify `_setup_claude_code` to drop the templates/scripts/rubric/ bootstrap deployment lines.
8. Create `.devcontainer/unattended/devcontainer.json` with `containerEnv: { DOTFILES_INSTALL_AGENTIC: "1" }`.
9. Add transitional back-compat symlinks in `_setup_claude_code` (e.g.
   `ln -snf ~/.agentic/scripts ~/.claude/scripts`).
10. Update README.md "Two products" section.
11. Update `make test` to cover both opt-in paths.

### Phase 2: Remove back-compat symlinks (PR #47)

1. Remove the back-compat symlink lines from `_setup_claude_code`.
2. Remove any remaining "legacy rubric path" handling in dc-audit.sh.
3. Document the removal in CHANGELOG-style notes (commit message).

## Testing Strategy

- `tests/test-install.sh` updated: assert `~/.agentic/` does NOT exist after default install.
- New: assert `~/.agentic/scripts/ralph.sh` exists and is executable after `--with-agentic`.
- `tests/test-ralph.sh` updated to source `~/.agentic/lib/logging.sh` (the vendored copy).
- `tests/test-dc-audit.sh` works in standalone mode (no dotfiles install required).
- `make lint-devcontainers` advisory: assert unattended profile has `containerEnv` opt-in.
- Cross-platform: full matrix.

## Files

- Move (preserve git history): `claude-code/scripts/` -> `agentic/scripts/` `claude-code/templates/` -> `agentic/templates/` `claude-code/devcontainer-rubric.json` -> `agentic/devcontainer-rubric.json` `claude-code/egress-allowlist.txt` -> `agentic/egress-allowlist.txt` `claude-code/bootstrap/` -> `agentic/bootstrap/`
- Create: `agentic/README.md`, `bin/dc-audit.sh`, `.devcontainer/unattended/devcontainer.json`
- Modify: `install.sh` (CLI flags), `bootstrap/symlinks.sh` (`_setup_agentic`, modified `_setup_claude_code`), `README.md`, `tests/test-install.sh`, `tests/test-ralph.sh`, `tests/test-dc-audit.sh`, `Makefile` (`lint-devcontainers` target).
