# git-hooks

## Overview

Global git hooks installed via `core.hooksPath = ~/.config/git/hooks`. Two
hooks: `commit-msg` enforces conventional commits / no AI attribution / no
emoji, and `pre-commit` runs gitleaks against staged changes. Both delegate
to per-repo `*.local` overrides so individual projects can layer additional
checks.

## Requirements

### Hook deployment

- The installer MUST symlink `~/.config/git/hooks` to
  `<DOTFILES_DIR>/git/hooks/`.
- The installer MUST chmod +x every file in `<DOTFILES_DIR>/git/hooks/`
  before symlinking.
- When `DOTFILES_NO_GIT_HOOKS=1` is set, the installer MUST skip global
  hook deployment entirely.
- The dotfiles `git/.gitconfig` MUST set `core.hooksPath =
  ~/.config/git/hooks` so all repos inherit the global hooks.

### commit-msg: conventional commits

- The hook MUST require subjects matching:
  `^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z][a-z0-9-]*\))?:[[:space:]][a-z].+`
- The hook MUST require subject length >= 10 characters.
- The hook MUST allow merge commits (subject starts with `merge` or
  `Merge`) to pass through unchecked.
- The hook MUST exit non-zero with an explanatory message when any check
  fails.

### commit-msg: AI attribution

- The hook MUST block commits whose body contains attribution phrases
  matching `(generated|powered|created|written|assisted|produced|authored|
  built|made) (with|by).* (claude|anthropic|gpt|openai|copilot|gemini|
  cursor|windsurf|ai)` (case-insensitive).
- The hook MUST also block reverse-order phrases like
  `claude.*generated`.
- The hook MUST block any line containing `claude.com`, `anthropic.com`,
  `ai-generated`, or `ai generated`.
- Tool names appearing in technical context (file paths, config
  references) MUST NOT trigger the block.

### commit-msg: co-author lines

- The hook MUST block any commit whose body matches `co-authored-by:` or
  `co-authored by:` (case-insensitive).

### commit-msg: emoji

- The hook MUST block any commit message containing characters in the
  Unicode emoji ranges: U+1F000-1FAFF, U+2300-23FF, U+2600-27BF, U+2B50,
  U+2B55, U+FE00-FE0F, U+200D.
- If `perl` is unavailable, the emoji check MUST be silently skipped
  (degraded mode rather than hard failure).

### pre-commit: gitleaks

- The hook MUST run `gitleaks protect --staged --no-banner` if `gitleaks`
  is on PATH.
- Non-zero exit from gitleaks MUST block the commit with explanatory
  output (review findings, .gitleaksignore option, --no-verify escape).
- If `gitleaks` is not installed, the hook MUST exit 0 silently.

### Per-repo escape hatches

- Both hooks MUST execute `<git-dir>/hooks/<hook-name>.local` first if it
  is executable. Non-zero exit from the local hook MUST abort the global
  hook with the same exit code (allows repos to add stricter checks).
- For commit-msg, the hook MUST also fall back to `<git-dir>/hooks/
  commit-msg` (without `.local` suffix) if no `.local` variant exists, as
  long as it is not the same file as the global hook (recursion guard).

### Recursion safety

- The hook MUST set `DOTFILES_GLOBAL_HOOK_RUNNING=1` before doing any
  work. If this var is already set on entry, the hook MUST exit 0
  immediately (prevents infinite loop if a repo-level hook re-invokes
  the global one).

## Scenarios

### Scenario: Conventional commit accepted

GIVEN the user runs `git commit -m "feat(install): support --with-unattended flag"`
WHEN the global commit-msg hook runs
THEN the subject matches the conventional-commits regex
AND its length is >= 10
AND no AI attribution / co-author / emoji is present
AND the hook exits 0
AND the commit is created.

### Scenario: AI attribution rejected

GIVEN the user runs `git commit -m "fix: bug" -m "Generated with Claude Code"`
WHEN the global commit-msg hook runs
THEN the AI attribution regex matches `Generated.*Claude`
AND the hook prints `Commit message contains AI tool attribution`
AND exits 1
AND the commit is aborted.

### Scenario: gitleaks finds a secret

GIVEN the user staged a file containing `AWS_SECRET_ACCESS_KEY=AKIA...`
WHEN the user runs `git commit -m "feat: deploy script"`
THEN the global pre-commit hook runs gitleaks
AND gitleaks reports the AWS credential
AND exits non-zero
AND the commit is aborted.

### Scenario: Repo-local override layered on top

GIVEN a repo has `.git/hooks/commit-msg.local` that requires every subject
to start with a JIRA ticket like `FOO-123`
WHEN the user runs `git commit -m "feat: add login"` (no JIRA ticket)
THEN the global commit-msg hook delegates to `commit-msg.local` first
AND `commit-msg.local` exits non-zero
AND the commit is aborted before any global check runs.

### Scenario: Hook recursion guard

GIVEN the global commit-msg hook is invoked
AND a repo-level hook re-invokes the global hook (misconfigured)
WHEN the second invocation enters the global hook
THEN it sees `DOTFILES_GLOBAL_HOOK_RUNNING=1`
AND exits 0 immediately without re-running checks.

## Non-Behavior

- The hooks do NOT prevent `--no-verify` (intentional escape hatch).
- The hooks do NOT enforce a maximum subject length.
- The hooks do NOT enforce body wrapping or sign-off lines.
- The hooks do NOT auto-format the commit message (no rewrite).
- The pre-commit hook does NOT run linters or formatters (delegated to
  the project, not the dotfiles).
- The hooks do NOT verify GPG/SSH signatures (the signing setup is in the
  `git` capability; verification is git's responsibility).
