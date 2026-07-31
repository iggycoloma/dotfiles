# Dotfiles -- Project-Specific Claude Code Instructions

See `AGENTS.md` for shared guardrails, CLI tool preferences, and security model.
This file covers Claude-specific context for working in this repository.

## Design Philosophy

This repo is developer-specific, not project-specific. It installs universally useful
CLI tools and agentic coding tools (Claude Code, Codex CLI). For project-dependent tools
(gh, docker, kubectl, etc.), it supplies configuration surface (aliases, completions,
state persistence) without installing them. Projects own their own tooling; this repo
ensures the developer's preferences are ready.

When making changes, respect this boundary: don't add installation logic for tools that
belong to individual projects. Do add configuration, completions, and state persistence
for tools developers commonly encounter.

## Quality Gates

- `make lint` -- shellcheck all `.sh` files (CI blocks merge on failure)
- `make test` -- run full test suite (unit + packages + integration)
- `make test-unit` / `make test-packages` / `make test-integration` -- run individually

## Repository Architecture

This repo deploys a portable CLI environment. Key directories:

| Directory | Purpose |
|-----------|---------|
| `bootstrap/` | Environment detection, package installation, symlink management |
| `shell/` | Bash/zsh configs, aliases, functions, exports, completions |
| `git/` | Git config, global hooks (conventional commits, gitleaks) |
| `claude-code/` | Global Claude Code config (deployed to `~/.claude/`) |
| `codex/` | Global Codex CLI config (deployed to `~/.codex/`) |
| `config/` | Starship prompt, ripgrep defaults |
| `tests/` | 7 test suites (unit, integration, security, packages, functions) |

## Instruction File Layout

| File | Scope | Read by |
|------|-------|---------|
| `AGENTS.md` (root) | This repo | All AI tools (Cursor, Windsurf, etc.) |
| `CLAUDE.md` (root, this file) | This repo | Claude Code only |
| `.github/copilot-instructions.md` | This repo | GitHub Copilot |
| `claude-code/CLAUDE.md` | Global (all projects) | Claude Code (deployed to `~/.claude/`) |
| `codex/AGENTS.md` | Global (all projects) | Codex CLI (deployed to `~/.codex/`) |
| `copilot/copilot-instructions.md` | Global (all projects) | Copilot CLI (deployed to `~/.copilot/`) |

Project-specific instructions belong in root files. Global files should contain
only preferences and guardrails that apply across all repositories.

## Deny-list semantics

Guidance for maintaining `claude-code/settings.json`. It lives here rather than in
the globally-deployed `claude-code/CLAUDE.md` because it is repo-maintenance context:
useful when editing the deny lists, dead weight in every unrelated project's session.

`settings.json` has three kinds of deny entries; they do not share matching rules, so trust them differently.

- `Read(<glob>)` / `Write(<glob>)` / `Edit(<glob>)` -- real glob matching against the `file_path` argument. The primary boundary for credential paths; covers `.env*`, `~/.ssh/**`, `~/.aws/**`, etc.
- `Bash(<prefix>:*)` -- prefix match against the command string. `Bash(rm -rf:*)` blocks only commands literally starting with `rm -rf`, not `sudo rm -rf /`, `bash -c 'rm -rf /'`, `env rm -rf /`, `xargs rm -rf`, subshells, or pipes. A tripwire, never a security boundary.
- There is no hook-based Bash scan behind these. `pre-security.sh` guards file-path arguments only; the command-string scan was retired because it could not tell naming a path from opening one (see [docs/sandbox.md](docs/sandbox.md#why-there-is-no-bash-scan)). Credential reads from Bash are gated by `sandbox.credentials`, enforced by bwrap/Seatbelt.

### Three-tier responsibility model

Bash deny entries stay deliberately narrow. Each risk is defended at exactly one tier; do not duplicate across tiers.

- **Tier 1 -- file content (this layer defends).** Credential exposure is caught by the `Read`/`Write`/`Edit` globs in `settings.json` and the matching `pre-security.sh` path check, with `sandbox.credentials` covering the same paths for Bash subprocesses. Authoritative; new file-content guards belong here.
- **Tier 2 -- system state and network (sandbox/host defends).** The container boundary, OS sandbox (bwrap on Linux/WSL2, seatbelt on macOS), and the `sudo:*` deny are the gates. Do NOT add per-binary Bash denies for `iptables`, `systemctl`, `mkfs`, `dd`, `shutdown`, etc. -- they need sudo to do anything meaningful and sudo is already blocked, so each one only adds a redundant prompt.
- **Tier 3 -- remote / shared (server defends).** Trunk protection, required reviews, and push restrictions live on the remote (GitHub branch protection rules). Do NOT simulate with `Bash(git push * main*)` tripwires -- the prefix matcher does not handle inline wildcards reliably, and remote protection is the only authoritative defense against an accidental trunk push.

Adding a new deny entry? Prefer `Read`/`Write`/`Edit` with a glob when the risk is about file contents; use `Bash(...)` only as a best-effort tripwire for a local-state footgun.

### What stays in the Bash deny list

Local-state footguns where no other layer catches a typo: `rm -rf` variants, `git reset --hard`, `git clean -fdx`/`-fd`, `git filter-branch`/`filter-repo`, recursive `chmod` to dangerous modes, recursive `chown`, plain `git push --force` and `git push -f` (asymmetric -- the safe variant has a separate path), destructive docker ops (`system prune`, `volume rm`), and the `sudo:*` upstream gate. These are friction speed bumps, not security boundaries.

### Force-push policy

`git push --force-with-lease` is allowed -- use it for stacked-PR rebases. The lease refuses to overwrite a ref that has moved since your last fetch, which is the actual safety property worth preserving locally. Plain `git push --force` and `git push -f` stay denied because they have no such check.

### Codex / Copilot parity

By design, Codex CLI and GitHub Copilot CLI get no equivalent Bash deny list -- their config formats expose no per-command deny syntax. Codex relies on its native `sandbox_mode` (`workspace-write` on hosts, `danger-full-access` in containers, where the container itself is the boundary); Copilot relies on interactive permission prompts plus `--deny-tool` flags. Both pick up the shared `pre-security.sh` hook for Tier 1, but not at Claude Code's coverage. On Codex only `apply_patch` is scanned (needs Codex >= 0.123.0); credential-*read* blocking is unavailable at any version, since its `read_file` and `grep` handlers fire no `PreToolUse` hook, and it has no `sandbox.credentials` equivalent. Treat Tier 1's read-side guarantee as Claude-Code-only; see [`docs/agentic-tooling.md`](docs/agentic-tooling.md#coverage-is-not-symmetric-across-tools).

## Devcontainer Behavior

Claude Code and Codex CLI are installed as native binaries everywhere, hosts
included -- that is not devcontainer-specific.

The installer auto-detects devcontainers and Codespaces. What is specific to
those environments:
- AI tool configs are copied fresh from dotfiles on every rebuild
- Credential state persists via volume mounts or Codespaces storage
- Shell history, auth tokens, and sessions survive container rebuilds
- MCP configs (in settings.local.json) persist via the same volume mount as other Claude state
- Project-level .mcp.json files persist in the project repo naturally

## Testing Across Platforms

CI tests 13+ platform configurations. When making changes to bootstrap or shell
scripts, consider cross-platform impact: Ubuntu (20.04/22.04/24.04), Debian
(11/12), Alpine (musl), macOS (15/26), and Codespaces simulation.
