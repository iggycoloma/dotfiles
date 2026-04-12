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

## Devcontainer Behavior

The installer auto-detects devcontainers and Codespaces. In these environments:
- Claude Code and Codex CLI are installed as native binaries
- AI tool configs are copied fresh from dotfiles on every rebuild
- Credential state persists via volume mounts or Codespaces storage
- Shell history, auth tokens, and sessions survive container rebuilds
- MCP configs (in settings.local.json) persist via the same volume mount as other Claude state
- Project-level .mcp.json files persist in the project repo naturally

## Testing Across Platforms

CI tests 13+ platform configurations. When making changes to bootstrap or shell
scripts, consider cross-platform impact: Ubuntu (20.04/22.04/24.04), Debian
(11/12), Alpine (musl), macOS (15/26), and Codespaces simulation.
