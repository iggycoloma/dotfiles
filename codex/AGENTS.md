# Codex Global Instructions (Claude-Parity)

Use these rules to mirror the existing Claude Code setup.

## Core Guardrails

- Never access secrets or credential files without explicit user approval.
- Treat these paths as sensitive: `.env*`, `credentials.json`, `.credentials`, `secrets.yaml`, `secrets.json`, `.aws/credentials`, `.ssh/id_rsa`, `.ssh/id_ed25519`, `.git/config`, `*.pem`, `*.key`, `*.p12`, `*.pfx`.
- Deny path traversal patterns (for example paths containing `../`) unless the user explicitly asks and confirms.
- Do not add decorative emoji characters to code, docs, or commit messages.
- Use conventional commits and do not include AI attribution or `Co-Authored-By` lines.

## Working Style

- Prefer `rg` for content search and `rg --files` for file discovery.
- Keep changes minimal and focused; do not refactor unrelated code.
- Run relevant tests/lint after changes when practical and report what was run.
- If asked for a review, prioritize bugs/regressions/security issues first, then style.

## Claude-Style Workflow Intents

When user intent matches these commands, use the equivalent workflow:

- `context-prime`: load README + key project files, summarize stack, git state, and active work.
- `commit`: inspect staged/uncommitted diff, propose conventional commit message, then commit.
- `pr-create`: summarize changes, draft a complete PR body, and provide/run `gh pr create`.
- `review-pr`: fetch PR info/diff/checks and produce severity-ordered findings.
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
