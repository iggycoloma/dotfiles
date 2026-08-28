# Feature Specification: Git Hooks

**Branch**: `005-git-hooks` | **Date**: 2026-04-01 | **Status**: Implemented

## User Scenarios & Testing

### User Story 1 - Conventional commits enforced everywhere (Priority: P1)

A developer running `git commit` in any repo on the machine gets the conventional-commits regex applied.
AI attribution and emoji are blocked.
Merge commits pass through.

**Independent Test**: In any repo, attempt `git commit -m "wip"` -> hook rejects (too short, no conv-commit prefix).
`git commit -m "feat: add x"` -> accepted.

**Acceptance Scenarios**:
```
GIVEN a developer runs `git commit -m "feat(install): support --with-unattended flag"` in any repo
WHEN the global commit-msg hook runs
THEN the regex matches conventional commits
  AND length >= 10 chars passes
  AND the commit is created (exit 0)
```

```
GIVEN a developer runs `git commit -m "fix: bug" -m "Generated with Claude Code"`
WHEN the global commit-msg hook runs
THEN the AI attribution check matches "Generated.*Claude"
  AND the hook prints "Commit message contains AI tool attribution"
  AND exits 1 (commit aborted)
```

### User Story 2 - Gitleaks blocks staged secrets (Priority: P1)

A developer accidentally stages a file containing an API key.
The pre-commit hook catches it before it reaches the local commit.

**Independent Test**: Stage a file with `AWS_SECRET_ACCESS_KEY=AKIA...`, attempt commit, assert hook exits non-zero with gitleaks output.

**Acceptance Scenarios**:
```
GIVEN gitleaks is installed
  AND a staged file contains "AWS_SECRET_ACCESS_KEY=AKIA..."
WHEN `git commit -m "feat: deploy script"` runs
THEN the global pre-commit hook runs gitleaks --staged
  AND gitleaks reports the AWS credential
  AND the commit is aborted
```

### User Story 3 - Per-repo escape hatch (Priority: P2)

A repo can layer additional checks via `.git/hooks/commit-msg.local` or `.git/hooks/pre-commit.local`.
The global hook delegates to the local first.

**Independent Test**: Add a `commit-msg.local` that requires `FOO-NNN`; attempt commit without ticket; assert global hook delegates and the local hook fails the commit.

**Acceptance Scenarios**:
```
GIVEN .git/hooks/commit-msg.local requires "FOO-123" prefix
WHEN `git commit -m "feat: add login"` runs (no ticket)
THEN the global commit-msg hook delegates to .local first
  AND .local exits non-zero
  AND the commit is aborted before any global check runs
```

### Edge Cases

- **Recursion guard**: If a repo-level hook re-invokes the global hook, `DOTFILES_GLOBAL_HOOK_RUNNING=1` short-circuits the second invocation to exit 0.
- **No perl available**: emoji check silently skipped (degraded mode).
- **No gitleaks**: pre-commit hook exits 0 silently (no installation prompt).
- **Merge commits**: subject starting with `Merge` or `merge` passes through unchecked.

## Requirements

### Functional Requirements

- **FR-001** Installer MUST symlink `~/.config/git/hooks` to dotfiles `git/hooks/`.
- **FR-002** Installer MUST chmod +x every hook before symlinking.
- **FR-003** `DOTFILES_NO_GIT_HOOKS=1` MUST skip hook deployment entirely.
- **FR-004** Dotfiles `git/.gitconfig` MUST set `core.hooksPath = ~/.config/git/hooks`.
- **FR-005** commit-msg MUST enforce conventional-commit subject regex with allowed types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert.
- **FR-006** commit-msg MUST require subject length >= 10 chars.
- **FR-007** commit-msg MUST allow merge commits (subject ^[Mm]erge\b) to pass.
- **FR-008** commit-msg MUST block AI attribution (case-insensitive patterns).
- **FR-009** commit-msg MUST block `co-authored-by:` lines.
- **FR-010** commit-msg MUST block emoji characters in Unicode emoji ranges.
- **FR-011** pre-commit MUST run `gitleaks protect --staged --no-banner` if gitleaks is on PATH; silent no-op otherwise.
- **FR-012** Both hooks MUST execute `<git-dir>/hooks/<hook>.local` first if executable; non-zero exit aborts.
- **FR-013** Both hooks MUST set `DOTFILES_GLOBAL_HOOK_RUNNING=1` to prevent recursion.

### Key Entities

- **Hook**: `commit-msg | pre-commit`.
  Each has a global and an optional `.local` variant.
- **Local override**: `<git-dir>/hooks/<hook>.local` -- runs first; non-zero exit aborts the global.

## Success Criteria

- **SC-001** test-security-hook.sh covers >= 89 cases across conv commits, AI attribution, emoji, recursion, merge passthrough.
- **SC-002** No CI commit ever bypasses the hook (`--no-verify` audit log clean).
- **SC-003** Per-repo `.local` hooks measured running first (test coverage).
- **SC-004** gitleaks finding rate of zero in dotfiles repo's own CI.

## Assumptions

- The user's shell has `set -euo pipefail` honored by hook scripts.
- `perl` is available on >=95% of hosts; if missing, emoji check is acceptable to skip.
- Repos that need stricter checks add `.local` hooks themselves.
