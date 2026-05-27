# Rename agentic-harness -> unattended-harness -- Tasks

## 1. Author the rename change folder

- [x] 1.1 Create `archive/2026-04-22-rename-agentic-to-unattended/`.
- [x] 1.2 Write `proposal.md` (intent, scope, approach, acceptance).
- [x] 1.3 Write `design.md` (paired-delta architecture, decisions).
- [x] 1.4 Write paired delta specs: `specs/agentic-harness/spec.md` (REMOVED everything) and `specs/unattended-harness/spec.md` (ADDED everything restated with new names).

## 2. Apply the rename in the canonical spec tree

- [x] 2.1 `git mv openspec/specs/agentic-harness/ openspec/specs/unattended-harness/`.
- [x] 2.2 In the renamed `spec.md`, update first-line heading to `# unattended-harness`.
- [x] 2.3 Replace every `agentic/` path with `unattended/`.
- [x] 2.4 Replace every `~/.agentic/` deploy path with `~/.unattended/`.
- [x] 2.5 Replace `--with-agentic` / `--without-agentic` flags with `--with-unattended` / `--without-unattended`.
- [x] 2.6 Replace `DOTFILES_INSTALL_AGENTIC` env var with `DOTFILES_INSTALL_UNATTENDED`.
- [x] 2.7 Refresh the overview paragraph to call out the rename and the new vocabulary distinction (agentic = interactive tools, unattended = autonomous-loop stack).

## 3. Update the in-flight change folder

- [x] 3.1 `git mv add-tier-2-trust-model/specs/agentic-harness/ .../specs/unattended-harness/`.
- [x] 3.2 Update the delta spec heading to `# unattended-harness --Change Delta (add-tier-2-trust-model)`.
- [x] 3.3 Replace path/flag references in proposal.md, design.md, tasks.md.

## 4. Update project-level docs

- [x] 4.1 `openspec/project.md` -- update the "Opt-in for high-risk surface" bullet.
- [x] 4.2 `openspec/config.yaml` -- update the context block.
- [x] 4.3 `openspec/AGENTS.md` -- no changes required (does not reference the old name).
- [ ] 4.4 `docs/spec-comparison/COMPARISON.md` -- update sections that cite the capability by name; explicitly note the rename as an additional finding in section 6 (refactor/removal handling).

## 5. Verify

- [ ] 5.1 `grep -rn 'agentic-harness' openspec/` -- expect hits only in `archive/2026-04-15-extract-agentic-harness/` and this change folder.
- [ ] 5.2 `grep -rn 'with-agentic\|DOTFILES_INSTALL_AGENTIC' openspec/` --expect hits only in archive folders.
- [ ] 5.3 Read the renamed `specs/unattended-harness/spec.md` end-to-end; confirm no internal references to the old name remain.
