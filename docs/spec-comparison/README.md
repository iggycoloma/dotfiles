# Spec-format comparison: OpenSpec vs SpecKit

This directory reverse-engineers the dotfiles repo into a parallel set of specification documents in two competing spec-driven-development (SDD) formats:

- [**OpenSpec**](https://github.com/Fission-AI/OpenSpec) -- change-proposal-driven, with delta specs (ADDED / MODIFIED / REMOVED) and an archive flow that merges deltas into canonical specs.
- [**SpecKit**](https://github.com/github/spec-kit) -- phase-gated (constitution -> specify -> clarify -> plan -> tasks -> analyze -> implement) with prioritized user stories, numbered functional requirements, and a Constitution Check gate.

The point is to compare the formats by writing real documents from the same source material, not to install or run either tool.
The on-disk layout mirrors each tool's expected layout so the documents look and read like the real thing.

## How to read this

Start with `COMPARISON.md` -- the side-by-side analysis with concrete examples from the docs in this tree.
Then drill into either format directory to see the documents in their native shape.

### Recommended reading order

1. `COMPARISON.md` -- the punchline; pick this up first
2. `openspec/project.md` and `spec-kit/memory/constitution.md` -- the project-level docs side by side
3. `openspec/specs/unattended-harness/spec.md` and `spec-kit/specs/010-unattended-harness/spec.md` -- the same capability written in each format.
   The capability was renamed from `agentic-harness` in PR #53; see `archive/2026-04-22-rename-agentic-to-unattended/` for the paired-delta rename pattern.
4. `openspec/changes/add-tier-2-trust-model/` and the corresponding pending plan revision in `spec-kit/specs/010-unattended-harness/` -- how each format handles in-flight change tracking
5. `openspec/changes/archive/2026-04-15-extract-agentic-harness/` and `openspec/changes/archive/2026-04-22-rename-agentic-to-unattended/` --how OpenSpec handles refactor + rename (no SpecKit equivalent for either; the asymmetry is itself a finding)

## Layout

```
docs/spec-comparison/
|-- README.md                 (this file)
|-- COMPARISON.md             (side-by-side analysis)
|-- openspec/                 (OpenSpec format)
|   |-- project.md
|   |-- AGENTS.md
|   |-- config.yaml
|   |-- specs/<capability>/spec.md      (12 capability specs)
|   `-- changes/                        (in-flight + archived examples)
|       |-- add-tier-2-trust-model/
|       `-- archive/
|           |-- 2026-04-15-extract-agentic-harness/
|           `-- 2026-04-22-rename-agentic-to-unattended/
`-- spec-kit/                 (SpecKit format)
    |-- memory/constitution.md
    |-- templates/commands/   (7 slash-command templates)
    `-- specs/NNN-<capability>/{spec.md, plan.md, tasks.md, ...}
```

## Capability inventory

The same 12 capabilities are specced in both formats.
Same scope per capability in each -- differences in the documents reflect format differences, not scope differences.
This is the only way the comparison lands.

| #  | ID                       | What it covers                                                                     |
|----|--------------------------|-------------------------------------------------------------------------------------|
| 1  | install                  | `install.sh` orchestration, environment detection, idempotent re-runs               |
| 2  | packages                 | CLI tool installation (apt/apk/brew + GitHub releases with checksum verification)   |
| 3  | shell                    | bash/zsh configs, aliases, functions, exports, completions, lazy-loading            |
| 4  | git                      | three-file git config model, delta integration, 44 aliases, SSH commit signing      |
| 5  | git-hooks                | global commit-msg + pre-commit (gitleaks)                                           |
| 6  | claude-code-config       | global ~/.claude/ payload (settings, hooks, agents, commands, statusline)           |
| 7  | codex-config             | global ~/.codex/ payload                                                            |
| 8  | copilot-config           | global ~/.copilot/ payload                                                          |
| 9  | devcontainer-support     | env detection, native AI-tool install, tiered state persistence                     |
| 10 | unattended-harness       | opt-in: ralph.sh, dc-audit, unattended devcontainer profile, mitmproxy egress allowlist (renamed from `agentic-harness` in PR #53) |
| 11 | quality-gates            | `make lint`, 7 test suites, GitHub Actions matrix                                   |
| 12 | diagnostics              | `dotfiles-doctor`, shell profiling, install logging                                 |

## What this is *not*

- Not an installation.
  No `openspec init` or `specify init` was run.
  There is no `~/.claude/commands/opsx/` or project-root `.specify/` directory.
  The documents are reproductions of each tool's file shapes for comparison.
- Not exhaustive.
  Three SpecKit capabilities (#6, #9, #10) get the deep-dive treatment with `research.md`, `contracts/`, `data-model.md`, and `checklists/`.
  The other nine get the core spec/plan/tasks trio.
  OpenSpec gets one in-flight change folder and two archived change folders (the original extraction and the agentic -> unattended rename) -- enough to exercise ADDED / MODIFIED / REMOVED deltas across both refactors and renames without rewriting history for every PR.
- Not authoritative.
  This is a research artifact for evaluating the formats.
  The actual repo state is the code itself; if the two diverge, the code wins.
