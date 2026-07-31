# GitHub Copilot Instructions

Instructions for GitHub Copilot when working in this repository.
See `AGENTS.md` for full context shared across all AI coding tools.

## About This Repo

Portable dotfiles providing a developer-specific environment for local hosts,
devcontainers, and Codespaces. Installs universally useful CLI tools and agentic
coding tools. For project-dependent tools (gh, docker, kubectl), the repo supplies
configuration (aliases, completions, state persistence) but does not install them.

## Guardrails

- No emojis in code, docs, or commit messages
- Use conventional commits; no AI attribution or Co-Authored-By lines
- Never read .env, credentials, secrets, .pem, .key files
- Never access credential directories: ~/.ssh, ~/.aws, ~/.gnupg, ~/.azure, ~/.config/gcloud, ~/.config/gh, ~/.config/glab-cli, ~/.docker, ~/.kube, ~/.config/heroku, ~/.config/doctl, ~/.gradle, ~/.m2, ~/.minikube, ~/.cargo, ~/.gem, ~/.composer, ~/.stripe, ~/.dotfiles-state, ~/.copilot
- Never access credential files: ~/.npmrc, ~/.pypirc, ~/.netrc, ~/.git-credentials, ~/.pgpass, ~/.my.cnf, ~/.mongorc.js, *.tfvars, *.ppk, *.jks, *.keystore, *.pfx, *.p12, settings.local.json, ~/.claude/.credentials.json
- Deny path traversal patterns (`../`) unless explicitly confirmed

## Quality

- All shell scripts must pass `make lint` (shellcheck) before merging; CI enforces this
- Run `make test` to execute the full test suite locally (unit + packages + integration)

## Security Model

- Secret scanning via gitleaks pre-commit hook on all repos
- ~50 sensitive file/directory patterns blocked in AI tool configs and hooks
- Conventional commits enforced globally; AI attribution blocked
- SSH commit signing auto-detected from SSH agent

## MCP Servers

MCP servers are not installed by dotfiles. If one is configured, use it. Do not install
new MCP servers without explicit user request. MCP servers bypass credential deny lists.

## Working Style

- Keep changes minimal and focused; do not refactor unrelated code
- Run `make lint` and relevant tests after changes; report what was run
- If asked for a review, prioritize bugs/regressions/security issues first, then style
