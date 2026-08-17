# Global Instructions

## Guardrails

- No emojis in code, docs, or commit messages
- Use conventional commits; no AI attribution or Co-Authored-By lines
- Never read .env, credentials, secrets, .pem, .key files
- Never access credential directories: ~/.ssh, ~/.aws, ~/.gnupg, ~/.azure, ~/.config/gcloud, ~/.config/gh, ~/.config/glab-cli, ~/.docker, ~/.kube, ~/.config/heroku, ~/.config/doctl, ~/.gradle, ~/.m2, ~/.minikube, ~/.cargo, ~/.gem, ~/.composer, ~/.stripe, ~/.dotfiles-state, ~/.copilot
- Never access credential files: ~/.npmrc, ~/.pypirc, ~/.netrc, ~/.git-credentials, ~/.pgpass, ~/.my.cnf, ~/.mongorc.js, *.tfvars, *.ppk, *.jks, *.keystore, *.pfx, *.p12, settings.local.json, ~/.claude/.credentials.json
- Deny path traversal patterns (`../`) unless explicitly confirmed
- Never set repo-local `core.hooksPath`: it silently disables the global secret-scanning and commit-message hooks

## Command legibility (permissions, security, observability)

Your tool's permission checks and the session/audit log both read the literal command string -- the realtime gate and the audit trail share the same blind spot, so keep that string an honest record of what runs.

- Prefer built-in file-search and edit tools over shelling out to read, search, or edit files -- no permission prompt, structured output, and a typed log event instead of a raw shell string.
- Keep commands literal: do not hide paths, filenames, or credentials behind variables, `base64`/`xxd`, `eval`, command substitution `$(...)`, or a pipe into a shell (`... | sh`). These defeat the scan at runtime and make the log unsearchable and non-reproducible afterward.
- Complexity is fine; indirection is not. A long but literal pipeline is fully analyzable and lands as one clean log line -- prefer it over many opaque micro-calls.
- Reserve dynamic or indirect syntax for when the operation is genuinely impossible otherwise; when you must, keep any sensitive path or credential literal and note in one line why the wrapper is necessary.

## MCP Servers

MCP servers are not installed by dotfiles. If one is configured, use it. Do not install new MCP servers without explicit user request. MCP servers bypass credential deny lists.

## Shared conventions (read before working)

Cross-tool conventions are single-sourced in shared prompt files deployed alongside this one.
At the start of a session, read and apply:

- `~/.copilot/prompts/writing-style.md` -- communication style for explanations, reviews, and prose, plus what a handoff report must cover
- `~/.copilot/prompts/engineering-conventions.md` -- preferred CLI tools, code-comment policy, markdown formatting
- `~/.copilot/prompts/worktrees.md` -- operational rules for the `wt` worktree system, when the task involves worktrees

## Working Style

- Keep changes minimal and focused; do not refactor unrelated code
- Run relevant tests/lint after changes when practical and report what was run
- If asked for a review, prioritize bugs/regressions/security issues first, then style

## Worktrees (parallel agent work)

The operational rules live in `~/.copilot/prompts/worktrees.md`, listed under Shared conventions above -- read it before doing worktree work.

Copilot-specific publication policy, which is not shared because it differs per tool:

- Publication policy: commit locally in the worktree; the human reviews, pushes, and opens the PR. Push or open PRs yourself only when explicitly granted for the task.
