# Implementation Plan: Git Hooks

**Branch**: `005-git-hooks` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)

## Summary

Two global git hooks deployed via `core.hooksPath`. `commit-msg` enforces
conv-commits + no AI attribution + no emoji + min length. `pre-commit`
runs gitleaks. Both delegate to per-repo `.local` overrides first and
guard against recursion via env var.

## Technical Context

| Field             | Value                                                            |
|-------------------|------------------------------------------------------------------|
| Language/Version  | Bash; perl (for emoji regex); gitleaks (optional)                |
| Dependencies      | git, perl (~95% present), gitleaks (optional)                    |
| Storage           | `~/.config/git/hooks/` symlink                                   |
| Testing           | `tests/test-security-hook.sh` (89+ cases)                       |
| Target Platform   | All; perl-less platforms degrade to no-emoji-check               |
| Project Type      | Single Project                                                   |
| Performance Goals | Hook overhead < 100ms (does not slow down commits)               |
| Constraints       | Must not interfere with merge commits or amend                   |
| Scale/Scope       | 2 hooks, ~150 lines total                                        |

## Constitution Check

| Article                            | Status | Notes                                                       |
|------------------------------------|--------|-------------------------------------------------------------|
| I. Developer-Specific              | PASS   | Universal commit hygiene.                                   |
| II. Defense-in-Depth Security      | PASS   | Layer 3 of defense-in-depth (gitleaks + conv-commits + no AI). |
| III. Cross-Platform Parity         | PASS   | perl missing -> degraded; gitleaks missing -> silent skip.  |
| IV. Idempotent and Reversible      | PASS   | Symlink replacement; hook deactivates on `--no-verify`.     |
| V. Opt-In for High-Risk Surface    | PASS   | `DOTFILES_NO_GIT_HOOKS=1` opt-out for users who object.     |

## Project Structure

```
git/hooks/
|-- commit-msg
+-- pre-commit
claude-code/hooks/shared-patterns.sh    # Shared regex patterns (deduplication)
```

### Structure Decision

Single Project. Two hook scripts share regex patterns via a shared
sourced utility to avoid drift across the global git `commit-msg`
hook and Claude Code's content hooks. (Historically a third consumer
existed -- the now-removed `pre-commit-validate.sh` PreToolUse hook --
which is what motivated the extraction in the first place.)

## Complexity Tracking

| Violation                                     | Why Needed                                                                  | Simpler Alternative Rejected Because                                                  |
|-----------------------------------------------|-----------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| Pattern sharing across hooks vs constitution recommendation of file-per-concern | The regex catalog (AI attribution, emoji ranges) needs to stay consistent across multiple hook scripts. Extracting them to a shared sourced utility was the only way to guarantee parity; the catalog originally fed three hooks (`commit-msg`, `pre-commit-validate.sh`, `pre-code-no-emoji.sh`) and now feeds two -- the shared utility outlived the deprecated `pre-commit-validate.sh`. | Inline duplication in each file would inevitably drift; we discovered exactly this drift before extracting. |
