# Rename agentic-harness -> unattended-harness -- Proposal

> Archived 2026-04-22. The rename shipped as part of PR #53 (egress
> spec-linting pivot), which also moved the repo subdirectory
> `agentic/` -> `unattended/` and the deploy path `~/.agentic/` ->
> `~/.unattended/`. The capability spec rename in this change folder
> mirrors that repo-level rename in the OpenSpec docs.

## Intent

The capability historically called `agentic-harness` covers ralph,
dc-audit, and the hardened devcontainer profile. After PR #53 landed,
the repo vocabulary explicitly distinguishes:

- **"agentic"** -- the interactive AI tools the dotfiles always install
  (Claude Code, Codex CLI). These are agentic in the broad sense.
- **"unattended harness"** -- the opt-in autonomous-loop stack
  (`./install.sh --with-unattended`). This is the *only* part that
  involves running agents without supervision.

Calling the capability `agentic-harness` blurred this distinction. A
reader skimming the spec tree saw "agentic" and assumed the broader
toolset; in fact the spec was narrowly about the unattended autonomous
loop and its safety perimeter.

## Scope

In scope:

- Rename the OpenSpec capability folder
  `openspec/specs/agentic-harness/` -> `openspec/specs/unattended-harness/`.
- Update every doc that references the old name (project.md, AGENTS.md,
  the in-flight `add-tier-2-trust-model` change folder, COMPARISON.md).
- Update the in-repo paths inside the spec body: `agentic/` ->
  `unattended/`, `~/.agentic/` -> `~/.unattended/`, `--with-agentic` ->
  `--with-unattended`, `DOTFILES_INSTALL_AGENTIC` ->
  `DOTFILES_INSTALL_UNATTENDED`.

Out of scope:

- The historical archive entry
  `archive/2026-04-15-extract-agentic-harness/` stays untouched as a
  frozen snapshot of what was true at the time of extraction. Its delta
  specs correctly reference the *then-current* capability name.
- The interactive AI tools (Claude Code / Codex CLI) continue to use
  the word "agentic" in non-spec docs; this rename only affects the
  unattended-harness capability spec.

## Approach

Standard OpenSpec rename pattern, expressed as paired delta specs:

- `specs/agentic-harness/spec.md` -- one block of `## REMOVED
  Requirements` covering every previous requirement (the capability
  ceases to exist under this name).
- `specs/unattended-harness/spec.md` -- one block of `## ADDED
  Requirements` covering the same requirements, restated with the new
  repo/deploy/flag names.

This is heavier than a folder rename, but it makes the rename
reviewable: a delta-spec reader can confirm that every removed
requirement appears in the added set with only path/name changes (no
semantic loosening).

## Impact

- **Readers of `specs/`**: clearer that `unattended-harness` is the
  opt-in autonomous-loop capability, not "everything agentic."
- **In-flight change `add-tier-2-trust-model`**: targets the new
  capability name. Its delta spec now lives at
  `add-tier-2-trust-model/specs/unattended-harness/spec.md`.
- **Project.md / AGENTS.md / COMPARISON.md**: updated to use the new
  vocabulary in the same change.
- **Historical archive**: untouched. The frozen `2026-04-15-extract-
  agentic-harness/` continues to reference the then-current name.

## Acceptance Criteria

- `openspec/specs/agentic-harness/` no longer exists.
- `openspec/specs/unattended-harness/spec.md` carries every requirement
  that was in the old spec, with paths and flags updated.
- `grep -r 'agentic-harness' openspec/` returns hits only in archive/
  (historical snapshots) and in this change folder.
- The in-flight `add-tier-2-trust-model` change references the new
  capability name throughout.
- COMPARISON.md sections 4, 5, 6, 7 still read correctly with the new
  name.
