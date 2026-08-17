# Codex Global Instructions

## Core Guardrails

- Never access secrets or credential files without explicit user approval
- Treat these paths as sensitive: `.env*`, `credentials.json`, `.credentials`, `secrets.yaml`, `secrets.json`, `*.pem`, `*.key`, `*.p12`, `*.pfx`
- Never access credential directories: `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.azure`, `~/.config/gcloud`, `~/.config/gh`, `~/.config/glab-cli`, `~/.docker`, `~/.kube`, `~/.config/heroku`, `~/.config/doctl`, `~/.gradle`, `~/.m2`, `~/.minikube`, `~/.cargo`, `~/.gem`, `~/.composer`, `~/.stripe`, `~/.dotfiles-state`, `~/.copilot`
- Never access credential files: `~/.npmrc`, `~/.pypirc`, `~/.netrc`, `~/.git-credentials`, `~/.pgpass`, `~/.my.cnf`, `~/.mongorc.js`, `*.tfvars`, `*.ppk`, `*.jks`, `*.keystore`, `*.pfx`, `*.p12`, `settings.local.json`, `~/.claude/.credentials.json`
- Deny path traversal patterns (for example paths containing `../`) unless the user explicitly asks and confirms
- Never set repo-local `core.hooksPath`: it silently disables the global secret-scanning and commit-message hooks
- Do not add decorative emoji characters to code, docs, or commit messages
- Use conventional commits and do not include AI attribution or `Co-Authored-By` lines

## Command legibility (permissions, security, observability)

Your tool's permission checks and the session/audit log both read the literal command string -- the realtime gate and the audit trail share the same blind spot, so keep that string an honest record of what runs.

- Prefer built-in file-search and edit tools over shelling out to read, search, or edit files -- no permission prompt, structured output, and a typed log event instead of a raw shell string.
- Keep commands literal: do not hide paths, filenames, or credentials behind variables, `base64`/`xxd`, `eval`, command substitution `$(...)`, or a pipe into a shell (`... | sh`). These defeat the scan at runtime and make the log unsearchable and non-reproducible afterward.
- Complexity is fine; indirection is not. A long but literal pipeline is fully analyzable and lands as one clean log line -- prefer it over many opaque micro-calls.
- Reserve dynamic or indirect syntax for when the operation is genuinely impossible otherwise; when you must, keep any sensitive path or credential literal and note in one line why the wrapper is necessary.

## MCP Servers

MCP servers are not installed by dotfiles. If one is already configured, use it. Do not install or configure new MCP servers without explicit user request. They run as child processes with full filesystem and network access, and bypass the credential deny lists above.

## Shared conventions (read before working)

Cross-tool conventions are single-sourced in shared prompt files deployed alongside this one.
At the start of a session, read and apply:

- `~/.codex/prompts/writing-style.md` -- communication style for explanations, reviews, and prose, plus what a handoff report must cover
- `~/.codex/prompts/engineering-conventions.md` -- preferred CLI tools, code-comment policy, markdown formatting
- `~/.codex/prompts/worktrees.md` -- operational rules for the `wt` worktree system, when the task involves worktrees

### Codex-specific communication corrections

The baseline bias compresses explanations too aggressively; actively counteract it:

- Do not omit reasoning simply because the conclusion can be stated briefly.
- For architectural or design decisions, explain the important "why" and surface meaningful tradeoffs and consequences without waiting to be asked.

## Working Style

- Keep changes minimal and focused; do not refactor unrelated code
- Run relevant tests/lint after changes when practical and report what was run
- If asked for a review, prioritize bugs/regressions/security issues first, then style

## Claude-Style Workflow Intents

When user intent matches these commands, use the equivalent workflow:

- `context-prime`: load README + key project files, summarize stack, git state, and active work.
- `commit`: inspect staged/uncommitted diff, propose conventional commit message, then commit.
- `pr-create`: summarize changes, draft a complete PR body, and provide/run `gh pr create`.
- `review-pr`: fetch a PR, MR, or the working diff; judge correctness, ordering, observability, repo fit and mechanism level; label each finding blocking or non-blocking; and name both the smallest correct change and the best available one.
- `debug`: gather evidence, form hypotheses, identify root cause, implement minimal fix, add tests.
- `test`: generate or update tests for changed behavior and run relevant suite.
- `dependencies`: check outdated/vulnerable deps, classify risk, and update safely.
- `security-audit`: scan for credential leaks, injection risk, authz gaps, and dependency CVEs.
- `feature-spec`: produce a structured spec with stories, acceptance criteria, edge cases, and scope.
- `pipeline`: run PM -> Architect -> Implementer -> QA stages with user checkpoints.

## Pipeline Rules

- Stage 1 (PM): create spec with clear acceptance criteria.
- Stage 2 (Architect): validate design and write ADR-level decisions.
- Stage 3 (Implementer): build exactly to spec/ADR and add tests.
- Stage 4 (QA): verify requirements, run checks, and decide `DONE` vs `NEEDS_WORK`.
- Pause between stages for user review before proceeding.

## Worktrees (parallel agent work)

The operational rules live in `~/.codex/prompts/worktrees.md`, listed under Shared conventions above -- read it before doing worktree work.

Codex-specific publication policy, which is not shared because it differs per tool:

- Publication policy: commit locally in the worktree; the human reviews, pushes, and opens the PR. Push or open PRs yourself only when explicitly granted for the task.
