# Dotfiles Repository -- Agent Instructions

Shared instructions for all AI coding tools working in this repository.
Global tool-specific configs live in `claude-code/CLAUDE.md` (deployed to `~/.claude/`)
and `codex/AGENTS.md` (deployed to `~/.codex/`).

## About This Repo

Portable dotfiles that lay down a productive, agentic coding environment on local
hosts (macOS/Linux), VS Code devcontainers, and GitHub Codespaces. A single
`install.sh` detects the environment and adapts automatically. It is safe to re-run.

This repo provides a **developer-specific** environment, not a project-specific one.
It installs universally useful shell tools (rg, fd, bat, fzf, etc.) and deeply
integrates agentic coding tools (Claude Code, Codex CLI). For project-dependent
tools (gh, docker, kubectl, mise, uv), the repo supplies configuration -- aliases,
completions, state persistence -- but does not install them. Projects bring their
own tooling via `devcontainer.json`; this repo ensures the developer's workflow is
ready when they arrive.

Tested platforms: Ubuntu (20.04/22.04/24.04), Debian (11/12), Alpine, macOS (15/26),
GitHub Codespaces.

## Guardrails

- No emojis in code, docs, or commit messages
- Use conventional commits; no AI attribution or Co-Authored-By lines
- Never read .env, credentials, secrets, .pem, .key files
- Never access credential directories: ~/.ssh, ~/.aws, ~/.gnupg, ~/.azure, ~/.config/gcloud, ~/.config/gh, ~/.docker, ~/.kube, ~/.config/heroku, ~/.config/doctl, ~/.gradle, ~/.m2, ~/.minikube, ~/.cargo, ~/.gem, ~/.composer, ~/.stripe, ~/.dotfiles-state
- Never access credential files: ~/.npmrc, ~/.pypirc, ~/.netrc, ~/.git-credentials, ~/.pgpass, ~/.my.cnf, ~/.mongorc.js, *.tfvars, *.ppk, *.jks, *.keystore, *.pfx, *.p12
- Deny path traversal patterns (`../`) unless the user explicitly asks and confirms

## Quality

- All shell scripts must pass `make lint` (shellcheck) before merging; CI enforces this
- Run `make test` to execute the full test suite locally (unit + packages + integration)
- Run `shellcheck` on any new or modified `.sh` file before committing

## Preferred CLI Tools

Use these tools when available instead of standard Unix alternatives:

| Instead of | Use | When |
|-----------|-----|------|
| `grep` (pattern search) | `rg` (ripgrep) | Text/regex search across files |
| `grep` (structural) | `sg` (ast-grep) | Finding code patterns by AST structure |
| `find` | `fd` | Finding files by name/pattern |
| `diff` | `difft` (difftastic) | Comparing files (AST-aware, ignores formatting noise) |
| `sed` | `sd` | Find/replace with PCRE regex |
| `cat` (highlighted) | `bat` | Viewing files with syntax highlighting |
| `wc -l` / `cloc` | `scc` | Code statistics (LOC, complexity, languages) |
| manual YAML editing | `yq` | YAML/TOML/XML queries and edits (preserves comments) |
| `jq` | `jq` | JSON processing (keep using jq, it's the standard) |
| `df` | `duf` | Disk free with color-coded bars |
| `du` | `dust` | Directory disk usage as a visual tree |
| `ps` | `procs` | Process viewer with color and search |

## Security Model

Defense-in-depth across multiple layers:

- **Secret scanning**: gitleaks pre-commit hook on all repos via `core.hooksPath`
- **Credential blocking**: ~50 sensitive file/directory patterns blocked in AI tool configs and hooks
- **Conventional commits**: enforced globally; AI attribution and Co-Authored-By blocked
- **SSH commit signing**: auto-detected from SSH agent (prefers ed25519)
- **Path traversal**: blocked unless explicitly approved

## Installation Toggles

These environment variables control what `install.sh` installs:

| Variable | Effect |
|----------|--------|
| `DOTFILES_NO_AI_TOOLS=1` | Skip agentic CLIs, ast-grep, difftastic, and AI config |
| `DOTFILES_NO_ATUIN=1` | Skip atuin and bash-preexec |
| `DOTFILES_NO_GIT_HOOKS=1` | Skip global git hooks |
| `DOTFILES_NO_STATE_PERSISTENCE=1` | Skip state persistence tier detection |
| `DOTFILES_NO_SSH_SIGNING=1` | Skip SSH commit signing auto-detection |

## Working Style

- Keep changes minimal and focused; do not refactor unrelated code
- Run `make lint` and relevant tests after changes; report what was run
- If asked for a review, prioritize bugs/regressions/security issues first, then style
