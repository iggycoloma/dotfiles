# Dotfiles Repository -- Agent Instructions

Canonical, model-neutral instructions for all AI coding tools working in this repository.
The adjacent `CLAUDE.md` imports this file via `@AGENTS.md` and adds only Claude-specific content.

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

When making changes, respect this boundary: don't add installation logic for tools
that belong to individual projects. Do add configuration, completions, and state
persistence for tools developers commonly encounter.

Tested platforms: Ubuntu (20.04/22.04/24.04), Debian (11/12), Alpine, macOS (15/26),
GitHub Codespaces. CI tests 13+ platform configurations; when changing bootstrap or
shell scripts, consider cross-platform impact.

## Agent instruction architecture

### Sources are authoritative; deployments are outputs

The tracked sources in this repository are the single source of truth for every agent-instruction surface.
The files under `~/.claude`, `~/.codex`, and `~/.copilot` are generated or synchronized outputs of `bootstrap/symlinks.sh` (symlinks on hosts, managed copies in devcontainers) and must not drift silently:
edit the tracked source and redeploy, never the deployed copy.
`bin/prompt-drift.sh` (wired into `make lint`) verifies that deployed instruction files still match their tracked sources;
`bin/settings-drift.sh` does the same for the settings variants.

### Where a rule belongs

- Personal safety, tool choice, writing style, response calibration, and personal workflow live in the personal/shared prompt sources: `claude-code/CLAUDE.md`, `codex/AGENTS.md`, `copilot/copilot-instructions.md`, and the single-sourced fragments in `agent-prompts/`.
- Project-specific instructions belong in repository root files. The globally deployed files carry only preferences and guardrails that apply across all repositories -- repo details placed there load into every unrelated project's session.
- Workspace-specific authority, source order, publication policy, local runtime wrappers, and worktree layout live in the workspace prompt -- the instruction file at the workspace root that sits above individual checkouts.
- Team-owned code, test, canonical command, commit, MR, and review standards live in each repository's root `AGENTS.md`.
- Subtree `AGENTS.md` files contain only expensive-to-rediscover invariants and gotchas unique to that subtree.
- Multi-step or rare procedures use on-demand skills/runbooks, with a short mandatory trigger in an always-loaded file only when reliable activation has been demonstrated.
- Model-neutral policy is canonical in `AGENTS.md`. `CLAUDE.md` imports the adjacent `AGENTS.md` with `@AGENTS.md` and adds only Claude-specific calibration.

### How harnesses load these files

- Codex builds an instruction chain from its detected project root toward the working directory, loading at most one recognized instruction file per directory (`AGENTS.override.md`, then `AGENTS.md`), concatenated root-first under a combined size cap (32 KiB by default). A parent directory above the detected project root cannot be assumed to load, so a repository root `AGENTS.md` must be self-contained.
- Claude Code discovers `CLAUDE.md` files in parent directories of the working directory (loaded in full at launch) and in subdirectories (loaded on demand when files there are read), and supports `@file` imports, including `@AGENTS.md`.
- Claude imports organize content but do not make it task-conditional or reduce context cost: imported files are inlined at session start.
- A linked side document is not automatic Codex context. Keep always-required cross-harness rules in `AGENTS.md`; put conditional procedures outside it only behind an explicit trigger or a tested native skill.
- More-specific instructions override broader ones in both harnesses. Avoid contradictory copies: keep one canonical statement per rule and reference it.

### File map

| File | Scope | Read by |
|------|-------|---------|
| `AGENTS.md` (root, this file) | This repo | All AI tools; Claude via the `@AGENTS.md` import in `CLAUDE.md` |
| `CLAUDE.md` (root) | This repo | Claude Code only: `@AGENTS.md` plus Claude-specific content |
| `.github/copilot-instructions.md` | This repo | GitHub Copilot |
| `.claude/rules/*.md` | This repo | Claude Code path-scoped rules, loaded only when files matching their `paths:` globs are touched |
| `claude-code/CLAUDE.md` | Global (all projects) | Claude Code (deployed to `~/.claude/`) |
| `codex/AGENTS.md` | Global (all projects) | Codex CLI (deployed to `~/.codex/`) |
| `copilot/copilot-instructions.md` | Global (all projects) | Copilot CLI (deployed to `~/.copilot/`) |
| `agent-prompts/*.md` | Global (all projects) | Shared fragments, deployed to each tool's `prompts/` dir |

Cross-tool content (communication style, CLI tool preferences, comment policy,
markdown formatting, worktree operational rules, forge interaction) is single-sourced in
`agent-prompts/` and deployed to `~/.claude/prompts/`, `~/.codex/prompts/`, and
`~/.copilot/prompts/` by `bootstrap/symlinks.sh` (whole-directory, so a new
fragment needs no manifest entry). Claude loads it via native
`@~/.claude/prompts/...` imports (guaranteed, inlined at session start); Codex
and Copilot have no import mechanism, so their global files carry a "read these
at session start" directive (best-effort). For that reason security-critical
content stays inlined in every instruction file and remains covered by
`tests/test-consistency.sh`; only preferences and conventions belong in
`agent-prompts/`.

Two inlined exceptions are load-bearing and deliberately not shared:

- The credential deny lists in Guardrails.
- The repo-local `core.hooksPath` prohibition in the globally-deployed files.
  It silently disables gitleaks secret scanning, which is not something to
  deliver best-effort, so it stays inlined per tool and the test asserts it
  verbatim in all three global files.

Publication policy is also per-tool -- what an agent may push or open without
asking differs -- so it stays inlined alongside a pointer to the shared
fragment.

## Guardrails

- No emojis in code, docs, or commit messages
- Use conventional commits; no AI attribution or Co-Authored-By lines
- Never read .env, credentials, secrets, .pem, .key files
- Never access credential directories: ~/.ssh, ~/.aws, ~/.gnupg, ~/.azure, ~/.config/gcloud, ~/.config/gh, ~/.config/glab-cli, ~/.docker, ~/.kube, ~/.config/heroku, ~/.config/doctl, ~/.gradle, ~/.m2, ~/.minikube, ~/.cargo, ~/.gem, ~/.composer, ~/.stripe, ~/.dotfiles-state, ~/.copilot
- Never access credential files: ~/.npmrc, ~/.pypirc, ~/.netrc, ~/.git-credentials, ~/.pgpass, ~/.my.cnf, ~/.mongorc.js, *.tfvars, *.ppk, *.jks, *.keystore, *.pfx, *.p12, settings.local.json, ~/.claude/.credentials.json
- Deny path traversal patterns (`../`) unless the user explicitly asks and confirms

## Quality

- All shell scripts must pass `make lint` (shellcheck) before merging; CI enforces this
- Run `make test` to execute the full test suite locally (unit + packages + integration)
- `make test-unit` / `make test-packages` / `make test-integration` run suites individually
- Run `shellcheck` on any new or modified `.sh` file before committing

## Preferred CLI Tools

Single-sourced in [agent-prompts/engineering-conventions.md](agent-prompts/engineering-conventions.md) (rg, sg, fd, difft, sd, bat, scc, yq, and friends), which every deployed tool already loads via its `prompts/` directory.
Tools without a global config should read that fragment directly.

## Command legibility

Keep Bash command strings literal -- no paths or credentials hidden behind variables, encodings, `eval`, `$(...)`, or pipes into a shell -- because permission matching and the audit log both read only that string.
The full rules live in each tool's globally deployed instruction file (`claude-code/CLAUDE.md` Tool Use Discipline, `codex/AGENTS.md` Command legibility).

## Security Model

Defense-in-depth across multiple layers:

- **Secret scanning**: gitleaks pre-commit hook on all repos via `core.hooksPath`
- **Credential blocking**: ~50 sensitive file/directory patterns blocked in AI tool configs and hooks
- **Conventional commits**: enforced globally; AI attribution and Co-Authored-By blocked
- **SSH commit signing**: auto-detected from SSH agent (prefers ed25519)
- **Path traversal**: blocked unless explicitly approved
- **MCP posture**: No MCP servers installed by default. MCP servers run as child processes with full filesystem/network access and bypass credential deny lists. Do not install MCPs without explicit user request. MCP auth tokens belong in tool-specific local config (e.g., settings.local.json), never in dotfiles-tracked files.
- **Tool-specific deny lists**: follow a three-tier model -- file content defended locally, system/network defended by sandbox + `sudo:*`, remote/shared defended by branch protection. See `.claude/rules/deny-list-semantics.md` for the full rationale and what stays in vs out of the Bash deny list.

## Installation Toggles

These environment variables control what `install.sh` installs:

| Variable | Effect |
|----------|--------|
| `DOTFILES_NO_AI_TOOLS=1` | Skip agentic CLIs, ast-grep, difftastic, and AI config |
| `DOTFILES_NO_ATUIN=1` | Skip atuin and bash-preexec |
| `DOTFILES_NO_GIT_HOOKS=1` | Skip global git hooks |
| `DOTFILES_NO_STATE_PERSISTENCE=1` | Skip state persistence tier detection |
| `DOTFILES_NO_SSH_SIGNING=1` | Skip SSH commit signing auto-detection |

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

## Worktree system (wt)

Before editing `bin/wt`, `git/hooks/post-checkout`, `shell/completions/wt.bash`, `shell/completions/_wt`, or `tests/test-wt.sh`, read [docs/wt-maintenance.md](docs/wt-maintenance.md) first.
It carries the invariants and completion-system gotchas that are expensive to rediscover, and changes made without it have broken them before.

## Working Style

- Keep changes minimal and focused; do not refactor unrelated code
- Run `make lint` and relevant tests after changes; report what was run
- If asked for a review, prioritize bugs/regressions/security issues first, then style
