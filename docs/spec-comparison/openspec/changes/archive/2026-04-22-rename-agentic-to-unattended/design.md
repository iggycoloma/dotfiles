# Rename agentic-harness -> unattended-harness -- Design

## Architecture

A rename is the simplest possible OpenSpec change shape, but it exercises the format's strongest primitive: paired REMOVED + ADDED delta specs that together describe a capability moving wholesale to a new name.

```
specs/agentic-harness/spec.md  (delta)
  +-- ## REMOVED Requirements
  |     |-- Opt-in deployment (3 requirements)
  |     |-- Layout under ~/.agentic/
  |     |-- ralph.sh: autonomous loop
  |     |-- dc-audit.sh: devcontainer linter
  |     |-- Unattended devcontainer profile
  |     |-- Egress allowlist (mitmproxy)
  |     +-- Unattended deps
  +-- (no ADDED or MODIFIED)

specs/unattended-harness/spec.md  (delta)
  +-- ## ADDED Requirements
        |-- (every requirement above, restated)
        +-- New names: ~/.unattended/, --with-unattended,
            DOTFILES_INSTALL_UNATTENDED, unattended/...
```

The pair is mechanically equivalent to a folder rename in the canonical spec tree, but expressed as deltas it produces a reviewable artifact showing every requirement that moved (and confirming that no requirement was dropped or weakened along the way).

## Key Decisions

### Decision 1: Express the rename as REMOVED + ADDED, not as a folder mv

**Chosen**: write paired delta specs that REMOVE every requirement from `agentic-harness` and ADD every requirement to `unattended-harness`.

**Reason**: this is the change shape OpenSpec models well.
A reviewer sees the rename as a *behavior contract change*: same contract, new name.
Implicit folder renames hide whether anything else changed at the same time; explicit deltas force "every requirement that moved is listed."

**Trade-off**: heavier than `git mv`.
Worth it for the audit trail.

**Rejected**: a silent folder rename.
Loses the "did anything change besides the name?" confirmation that the paired delta gives the reviewer.

### Decision 2: Leave the historical archive untouched

**Chosen**: do NOT retroactively rename `archive/2026-04-15-extract-agentic-harness/` or its internal paths.

**Reason**: archived change folders are frozen historical snapshots.
At the time of that extraction, the capability was named `agentic-harness` and the repo subdirectory was `agentic/`.
Rewriting that archive would falsify the history.

**Trade-off**: a reader looking at the archive entry must mentally translate the old name.
The change-folder timeline makes the translation obvious (this rename change is dated after the extraction).

**Rejected**: rewriting historical archives to use the new name.
Sacrifices accuracy for grep-ability.

### Decision 3: Update the in-flight `add-tier-2-trust-model` change

**Chosen**: rename its internal `specs/agentic-harness/` to `specs/unattended-harness/` and update path references.

**Reason**: in-flight changes target the *current* capability name.
They have not yet been archived; their delta spec should match the canonical spec it will merge into.

**Trade-off**: small churn in the in-flight change folder.

## Implementation Strategy

1. Create `archive/2026-04-22-rename-agentic-to-unattended/` (this folder).
2. Write the paired REMOVED + ADDED delta specs.
3. `git mv openspec/specs/agentic-harness/ openspec/specs/unattended-harness/`.
4. Update path/flag references in the renamed `spec.md`.
5. `git mv openspec/changes/add-tier-2-trust-model/specs/agentic-harness/ .../specs/unattended-harness/`.
6. Update name references in `project.md`, `AGENTS.md`, `config.yaml`, `COMPARISON.md`.
7. Verify with `grep -r 'agentic-harness' openspec/` -- expect hits only in `archive/` and this rename change folder.

## Testing Strategy

No code change.
Verification is editorial:

- Read `specs/unattended-harness/spec.md`; confirm every requirement from the pre-rename spec is present.
- Read the paired delta specs in this archive entry; confirm REMOVED and ADDED sections mirror each other (same requirements, new names).
- `grep` checks that the old name appears only in the expected historical contexts.
