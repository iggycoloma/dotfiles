# Dotfiles Improvement Plan (Merged -- Final)

Date: 2026-04-09 (finalized 2026-04-10)
Sources: Codex CLI review + Claude Code review, merged and prioritized.

## Design Philosophy

This repo supplies a **developer-specific** environment, not a project-specific one.

| Responsibility | Belongs to |
|---|---|
| Install universally useful shell tools (rg, fd, bat, fzf, etc.) | This repo |
| Deeply integrate tools used everywhere (Claude Code, Codex CLI) | This repo |
| Supply preferences for project-dependent tools (aliases, completions, config, state persistence) | This repo |
| Install project-dependent executables (gh, docker, kubectl, uv, mise) | Project devcontainer.json |

Claude Code and Codex CLI are different from gh/docker/kubectl -- they're part of how the
developer works, not what they're working on. They get full treatment: install, config, hooks,
agents, commands, state persistence.

## Supported Platforms

Tested and supported: Ubuntu (20.04/22.04/24.04), Debian (11/12), Alpine, macOS (15/26), Codespaces.
WSL2 is covered via Ubuntu/Debian underneath.

Fedora/Arch: not supported, not a roadmap item. Remove detection code and narrow docs.
RHEL: irrelevant for dev environments. Skip.

---

## PR 1: Document design philosophy and tool tiers

The developer-specific vs project-specific distinction, the tool tier model, and the
supported platform scope need to be codified in the repo, not just this planning doc.

Files to update:

- **README.md**: Add a Design Philosophy section near the top, before "What's Included."
  Explain the repo's purpose (developer-specific environment for agentic coding on local
  hosts, devcontainers, and Codespaces), the tool tier model (core installs vs config
  surface for project-dependent tools), and why Claude Code/Codex get full treatment.
  Restructure the tool table to reflect tiers (Core, Shell Productivity, Developer
  Preferences). Narrow the platform support claims to tested platforms only.
- **AGENTS.md**: Update the "About This Repo" section to reflect the philosophy. Mention
  the tool tier distinction so AI tools understand what the repo does and doesn't install.
- **CLAUDE.md** (root): Add brief note about the design philosophy for Claude-specific
  context.

This PR also replaces the current ambiguous framing in the README (which implies all tools
are installed everywhere) with an honest accounting of what's installed vs what's configured.

## PR 2: Fix `dotfiles-doctor` git config check

The repo moved to `[include]`-based git config but dotfiles-doctor still expects
`~/.config/git/config` to be a symlink.

- Change doctor check from "is symlink" to "contains include for dotfiles git config"
- File: `shell/functions.sh` (~line 309)
- Add test coverage for the new check

## PR 3: Add `.github/copilot-instructions.md`

GitHub Copilot does NOT read `AGENTS.md`. Create `.github/copilot-instructions.md` with
guardrails, quality gates, and security sections extracted from `AGENTS.md`.

## PR 4: Clarify platform support scope

Folded into PR 1 for README changes. Separate PR for code changes:

- Remove Fedora/Arch detection code from `bootstrap/detect.sh`
- Remove any dnf/pacman references from `bootstrap/packages.sh`

## PR 5: Fully adopt duf and dust, decide on procs

`duf` (disk free) and `dust` (disk usage) are already installed but not documented/tested.
Both are read-only, zero-security-concern, single static binaries that fill clear gaps.

- Add duf and dust to README tool table, dotfiles-doctor, and test assertions
- `procs`: marginal value over htop/btop. Lean adopt (already installed, low maintenance
  cost to make official) but could remove without loss. Decision: adopt for now.

## PR 6: Add `hyperfine` to core installs

Single static binary from sharkdp (same developer as fd, bat). Universally useful for
benchmarking commands and shell startup. Fits existing `_install_tool` framework.

- Add to `_tool_config`, brew array, install call in `packages.sh`
- Add to README, dotfiles-doctor, AGENTS.md preferred tools table

## PR 7: Add `yazi` with config

Terminal file manager. Universally useful for navigating any codebase. Rust, async,
single binary from GitHub releases.

- Add to `packages.sh` install framework
- Create `config/yazi/` with yazi.toml, keymap.toml, theme.toml
- Add symlink in `symlinks.sh` for `~/.config/yazi`
- Add `y` wrapper function (cd to last dir on exit -- standard yazi pattern)
- Add to README, dotfiles-doctor

## PR 8: Add config surface for mise

Shell activation and completions only. Do NOT install mise or create global `.mise.toml`.
When a project's devcontainer installs mise and has a `.mise.toml`, it just works.

- Add `mise activate bash`/`mise activate zsh` to shell init (guarded with `command -v`)
- Add completions support

## PR 9: Add config surface for uv, xh, just

Aliases and completions for project-dependent tools. No installation.

- `uv`: completions, any useful aliases
- `xh`: completions, alias as curl alternative
- `just`: completions (projects that use justfiles install just themselves)

## PR 10: Evaluate carapace as completion supplement

Research whether carapace can supplement (not replace) existing completions. It covers
1000+ tools from a single binary, which would fill gaps for tools like yazi, hyperfine,
just, mise, uv, xh without per-tool completion wiring.

- Install carapace binary
- Test alongside existing zinit/per-tool completions for conflicts
- If it works as supplement: adopt. If conflicts: skip.

## PR 11: Add global Copilot CLI config surface

Copilot CLI uses `~/.copilot/` with file-based config, same pattern as Claude Code
and Codex. Supply preferences so when Copilot CLI is present (it ships with VS Code
and GitHub), the developer's guardrails are already there.

- Create `copilot/` directory in this repo with `copilot-instructions.md` (global instructions)
- Deploy to `~/.copilot/` via `_deploy_configs` (same pattern as claude-code/ and codex/)
- Add state persistence wiring for `~/.copilot/` in devcontainers
- Add `~/.copilot` to credential deny lists in AGENTS.md, claude-code/CLAUDE.md, codex/AGENTS.md
- Update README instruction file table

Note: Copilot CLI also supports `config.json` and `mcp-config.json` -- add those later
as part of the MCP strategy (PR 12).

## PR 12: Fix pre-commit hook false positive on tool name substrings

The pre-commit-validate.sh hook blocks commit messages containing "copilot" as a
substring, which prevents referencing the filename `copilot-instructions.md` in
commit messages. The regex `(copilot|gpt-)` is too broad -- it should match tool
attribution patterns, not filenames or technical references.

- Tighten the regex to match attribution phrases ("generated by", "powered by", etc.)
  rather than bare tool names
- Or add allowlist patterns for filenames and technical references
- File: `claude-code/hooks/pre-commit-validate.sh`

## PR 13: MCP strategy

Design doc for shared Model Context Protocol posture:
- Which MCP servers are allowed
- Configuration across Claude Code and Codex
- Security boundaries (credential access, network access)
- Devcontainer persistence for MCP server state

---

## Decided: Skip

| Item | Decision | Reason |
|---|---|---|
| Install `gh` | Not a bug | Repo correctly provides config surface; projects install it |
| Fedora/Arch support | Skip | Not relevant for dev environments |
| RHEL | Skip | Irrelevant for devcontainer-based development |
| Version pinning | Keep latest | Freshness matters more for personal dotfiles |
| `just` install | Config surface only (PR 9) | More project-dependent than developer-specific |
| Gemini CLI | Skip for now | Not on the same level as Claude Code/Codex yet |
| Aider/Goose/Kiro | Skip | Would spread agentic strategy too thin |
| dotbins | Skip | Incompatible with multi-architecture, lightweight philosophy |
| .cursorrules | Skip | Cursor reads AGENTS.md natively |
| nushell/fish | Skip | Too opinionated for defaults |
| broot/zellij | Skip | Overlaps with yazi/tmux respectively |
