# DRY Audit: Hooks and Instruction Files

Date: 2026-04-11

## Critical Security Gaps

### 1. Copilot credential deny lists are 43% incomplete

Both `copilot/copilot-instructions.md` and `.github/copilot-instructions.md` are missing:
- **11 directories**: ~/.config/heroku, ~/.config/doctl, ~/.gradle, ~/.m2, ~/.minikube,
  ~/.cargo, ~/.gem, ~/.composer, ~/.stripe, ~/.dotfiles-state, ~/.copilot
- **All credential file patterns**: ~/.npmrc, ~/.pypirc, ~/.netrc, ~/.git-credentials,
  ~/.pgpass, ~/.my.cnf, ~/.mongorc.js, *.tfvars, *.ppk, *.jks, *.keystore, *.pfx, *.p12

Root AGENTS.md has the complete list. These files were written with a subset.

### 2. Codex missing enterprise key formats

`codex/AGENTS.md` is missing `*.pfx` and `*.p12` from the credential file list.

## Duplication Issues

### 3. Six instruction files maintain separate guardrail copies

The credential deny list, CLI tool preferences, and working style are copy-pasted
across 6 files with no mechanism to keep them in sync:

| File | Directories | Files | CLI Tools | Working Style |
|------|------------|-------|-----------|---------------|
| AGENTS.md (root) | 18/18 | 13/13 | 12 tools | Complete |
| claude-code/CLAUDE.md | 18/18 | 13/13 | 9 tools | N/A (global) |
| codex/AGENTS.md | 18/18 | 11/13 | 9 tools (narrative) | Complete |
| copilot/copilot-instructions.md | 7/18 | 0/13 | 6 tools | Complete |
| .github/copilot-instructions.md | 7/18 | 0/13 | 0 tools | Complete |
| CLAUDE.md (root) | N/A | N/A | N/A | Delegates |

Root CLAUDE.md delegates to AGENTS.md -- this is the right pattern. The others duplicate.

### 4. Emoji detection implemented twice with different behavior

- `claude-code/hooks/pre-code-no-emoji.sh`: Allows markdown task symbols, uses perl
- `git/hooks/commit-msg`: No symbol allowlist, different unicode ranges

Both hooks serve different contexts (file content vs commit messages) so some divergence
is intentional, but the emoji detection ranges should be consistent.

### 5. Attribution detection duplicated in two hooks

- `claude-code/hooks/pre-commit-validate.sh`: PreToolUse hook for Claude Code
- `git/hooks/commit-msg`: Global git hook for all commits

Same regex in both. If one changes, the other drifts. No shared code.

## Approach

### Option A: Extract shared guardrails to a single file

Create a `GUARDRAILS.md` or similar that serves as the authoritative source, and have
instruction files reference it. Problem: most AI tools don't follow cross-file references.

### Option B: Keep duplication but fix gaps and standardize

Accept that each instruction file must be self-contained (tool limitation), but ensure
all copies are complete and identical. Add a test that validates consistency.

### Option C: Generate instruction files from a template

Build a script that generates tool-specific instruction files from a shared template.
Overkill for 6 files but eliminates drift permanently.

**Recommendation: Option B** -- fix the gaps now, add a consistency test to catch future drift.

### Shared hook logic

For the duplicated hook logic (emoji detection, attribution regex):
- Extract shared patterns to a sourced utility file
- Both hooks source the same definitions
- Reduces the "change one, forget the other" risk

## PR Plan

### PR 1: Fix credential deny list gaps

- Complete copilot/copilot-instructions.md deny lists (match root AGENTS.md)
- Complete .github/copilot-instructions.md deny lists
- Add *.pfx, *.p12 to codex/AGENTS.md
- Standardize CLI tool table across codex and copilot files
- Add duf, dust, procs, hyperfine to claude-code/CLAUDE.md preferred tools table

### PR 2: Extract shared hook patterns

- Create shared utility for emoji unicode ranges and attribution regex
- Source from both pre-code-no-emoji.sh and git/hooks/commit-msg
- Source from both pre-commit-validate.sh and git/hooks/commit-msg

### PR 3: Add consistency test

- Test that validates credential deny lists match across all instruction files
- Test that validates emoji ranges match between hooks
- Catches drift before it reaches main
