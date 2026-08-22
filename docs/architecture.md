# Architecture

How this repo is laid out, what it deploys, and the design choices behind
each piece. For the sandbox-specific architecture, see
[`sandbox.md`](sandbox.md).

## Scope boundary

This repo provides a **developer-specific** environment, not a
project-specific one:

| Responsibility                                                              | Belongs to               |
|-----------------------------------------------------------------------------|--------------------------|
| Install universally useful shell tools (rg, fd, bat, fzf, ...)              | This repo                |
| Deeply integrate tools the developer uses everywhere (Claude Code, Codex)   | This repo                |
| Supply config for project-dependent tools (aliases, completions, state)     | This repo                |
| Install project-dependent executables (gh, docker, kubectl, mise, uv, ...)  | Project devcontainer.json |

Aliases for tools that aren't installed are harmless -- a "command not found"
on `kubectl` when no kubectl is around is fine. When a project does bring the
tool in, the developer's preferences are already in place.

## Repository layout

```
dotfiles/
|-- install.sh                 # Main installer (orchestrates everything)
|-- Makefile                   # make lint (shellcheck + drift), make test
|-- AGENTS.md                  # Per-repo shared AI tool instructions
|-- CLAUDE.md                  # Per-repo Claude Code instructions
|-- bootstrap/
|   |-- detect.sh              # Environment + OS + package manager detection
|   |-- logging.sh             # Colored log functions
|   |-- packages.sh            # Tool installation (apt/apk/brew + GitHub releases)
|   |-- symlinks.sh            # Symlink/copy management + state persistence wiring
|   |-- completions.sh         # Shell completion setup (bash + zsh + zinit)
|-- shell/
|   |-- .bashrc, .bash_profile # Bash configuration
|   |-- .zshrc, .zprofile      # Zsh configuration (compinit caching, zprof support)
|   |-- aliases.sh             # 80+ aliases
|   |-- functions.sh           # 25+ utility functions (including dotfiles-doctor)
|   |-- exports.sh             # Environment variables (XDG, editor, themes)
|   +-- completion.sh          # Tool init (fzf, zoxide, atuin, direnv) with lazy-loading
|-- git/
|   |-- .gitconfig             # Shared git settings (delta, aliases, hooks)
|   |-- .gitignore_global      # Global gitignore
|   |-- .gitmessage            # Conventional commit template
|   +-- hooks/                 # Global git hooks (commit-msg, pre-commit)
|-- agent-hooks/               # Shared Claude/Codex hook implementations
|-- agent-skills/              # Portable Agent Skills deployed to Claude and Codex
|-- claude-code/
|   |-- CLAUDE.md              # Global Claude Code instructions
|   |-- settings.json          # Host variant (sandbox.enabled=true)
|   |-- settings.container.json # Container variant (sandbox.enabled=false)
|   |-- statusline.sh          # Status bar (git, context, model)
|   |-- hooks/                 # Claude hook wrappers + notify
|   |-- agents/                # PM, architect, implementer, QA, code reviewer
|   +-- commands/              # Remaining Claude-only legacy commands
|-- codex/
|   |-- AGENTS.md              # Global Codex instructions
|   |-- config.toml            # Host variant (sandbox_mode=workspace-write)
|   |-- config.container.toml  # Container variant (sandbox_mode=danger-full-access)
|   +-- hooks/                 # Codex hook wrappers + notify
|-- copilot/
|   +-- copilot-instructions.md # Global Copilot CLI instructions
|-- config/                    # Starship, ripgrep, bat, bottom, lazygit, yazi
|-- bin/                       # User-facing CLI tools (dc-audit, settings-drift, exec-modes, gh-repo-policy)
|-- unattended/                # Opt-in unattended coding harness (separate product)
|-- tests/                     # 9 test suites, 389 tests total
+-- .devcontainer/             # Example + reference devcontainer configurations
```

## Symlinks on hosts, copies in containers

`bootstrap/symlinks.sh` deploys config into `~/`. The strategy differs by tier:

- **Hosts**: symlinks from `~/<file>` -> `~/.dotfiles/<source>`. Edits to the
  repo immediately reflect in the running environment. The dotfiles repo must
  be present (typically at `~/.dotfiles`).
- **Devcontainers and Codespaces**: stomp-copies on every install. The repo
  doesn't have to exist inside the container -- the dotfiles run during
  `postCreateCommand`, copy the files, and exit. Re-running `install.sh` is
  the equivalent of `git pull` for config.

For settings files that have both host and container variants
(`claude-code/settings.json` vs `settings.container.json`, similarly for
codex), `_deploy_variant_file` in `bootstrap/symlinks.sh` picks the right
source based on `is_devcontainer()`. Codex's deployed `config.toml` is a
managed copy even on hosts because the installer appends a local absolute
notify hook path after selecting the variant.

The deployed home-dir instruction files (`~/.claude/CLAUDE.md`,
`~/.codex/AGENTS.md`, `~/.copilot/copilot-instructions.md`) are global
configs. They are user-scope, not project-scope. The tracked sources in the
dotfiles repo are authoritative: customize by editing the source and
re-running `install.sh` (or `bootstrap/symlinks.sh`), never by editing the
deployed copy -- `bin/prompt-drift.sh` flags such edits as drift, and a
devcontainer rebuild silently destroys them.

## State persistence

Agentic CLIs accumulate state (auth tokens, sessions, shell history, plans,
caches) that should survive container rebuilds. The persistence strategy is
tier-aware:

| Tier            | Detection                                             | Storage                                                | Persists rebuild? |
|-----------------|-------------------------------------------------------|--------------------------------------------------------|:----------------:|
| **Volume**      | `~/.dotfiles-state` exists and is a real directory    | Docker named volume mounted at `~/.dotfiles-state`     | Yes              |
| **Codespaces**  | `CODESPACES=true`                                     | `/workspaces/.codespaces/.persistedshare/dotfiles-state/` | Yes (platform) |
| **Ephemeral**   | Fallback                                              | Plain `~/.dotfiles-state/` directory                   | No               |

`bootstrap/detect.sh:detect_state_tier` returns the best tier; the home-dir
tool dirs (`~/.claude`, `~/.codex`, `~/.copilot`) are symlinked into the
chosen state location.

Local devcontainers add one mount line to `devcontainer.json`:

```jsonc
"mounts": [
  "source=${devcontainerId}-state,target=/home/vscode/.dotfiles-state,type=volume"
]
```

Codespaces handles persistence at the platform layer; no mount line is needed.

If no volume is present in a local devcontainer, the installer logs the exact
line to copy into `devcontainer.json`. The reference template in the
worktree-orchestrator repo (`examples/devcontainer/devcontainer.json`)
includes the line already.

### Ownership normalization

Docker creates fresh named volumes root-owned. The mount happens during
container start, *before* `postCreateCommand` runs `install.sh`. The
installer detects a root-owned `~/.dotfiles-state` and `sudo chown`
recursively before creating symlinks. Idempotent: once user-owned, the
volume stays that way across rebuilds.

### What persists, what refreshes

The volume holds **state**: credentials, auth tokens, shell history, sessions,
plans, caches. Anything the user accumulates while working.

Configs (`settings.json`, `CLAUDE.md`, hooks, agents, commands, skills)
refresh from the dotfiles repo on every install. That keeps the deployed
configs in sync with what you've committed to the repo. The user's own
`settings.local.json` (not tracked) is preserved.

## Devcontainer linting

Complementary linters live in `bin/`:

- [`bin/dc-audit.sh`](../bin/dc-audit.sh) -- security-focused linter for
  `devcontainer.json` files. Rubric-driven (`unattended/devcontainer-rubric.json`):
  image/feature pinning, `--security-opt=no-new-privileges`, resource caps,
  forbidden host credential mounts (unattended profile), `shutdownAction`,
  `updateRemoteUserUID`, `waitFor`. Profiles: `attended` (light safety) and
  `unattended` (hardened). `--fix` applies additive-only fixes (never
  overwrites or removes existing values). Wired into `make lint-devcontainers`.
- [`bin/sync-settings.sh`](../bin/sync-settings.sh) -- generates
  `claude-code/settings.container.json` from `settings.json`, swapping in the
  container-tier `.sandbox` block. `make sync-settings` writes it;
  `make lint` runs `--check` and fails when the committed copy is stale.
  Generating rather than mirroring makes host/container drift unrepresentable
  for the Claude pair.
- [`bin/exec-modes.sh`](../bin/exec-modes.sh) -- executable-bit gate. A file
  must carry `+x` iff it has a `#!` shebang and is not on the script's
  `NON_EXEC` list (`shell/`, `bootstrap/`, `templates/`, the test suites, and
  `agent-hooks/shared-patterns.sh` are sourced, never executed). Modes are read
  from the git index rather than `stat(2)`, so a working-tree `chmod` cannot
  mask a mismatch and the result does not depend on `core.fileMode`. `--fix`
  corrects both the index and the file. Wired into `make lint`; its own suite
  is `make test-exec-modes`. This matters because `claude-code/settings.json`
  invokes hooks by bare path with no interpreter -- a `pre-security.sh` that
  loses `+x` does not block a credential read, it never runs at all.
- [`bin/settings-drift.sh`](../bin/settings-drift.sh) -- drift linter, two
  classes. Host vs container: `claude-code/settings.json` vs
  `settings.container.json` outside `.sandbox`, and `codex/config.toml` vs
  `config.container.toml` outside `.sandbox_mode` (the Codex pair's only
  guard -- it differs by value and carries comments, so it cannot be
  generated). Deny parity: the `Read`/`Write`/`Edit` blocks in
  `permissions.deny[]` must match in content and order, so a path blocked for
  reads cannot stay writable through `Edit`. Wired into `make lint` as a
  prereq, so both are caught on every CI shellcheck run.

For the rubric, profiles, and the rationale behind splitting the drift check
into its own tool, see [`sandbox.md`](sandbox.md#devcontainerjson-linter).

## Modifying for your own use

The repo is meant to be forked and adapted:

1. **Fork on GitHub**, point your VS Code dotfiles settings at your fork.
2. **Edit the source files** in your fork. On hosts you'll see edits
   immediately (symlinks); in devcontainers re-run `install.sh`.
3. **Per-project extensions** -- drop a `.claude/settings.local.json` in any
   project (gitignored by default in Claude Code) to merge per-project
   permissions and domains on top of the global defaults. Same for
   `.codex/config.local.toml`.
4. **Per-devcontainer extensions** -- set environment variables in the
   `remoteEnv` block of the project's `devcontainer.json`:
   `DOTFILES_INSTALL_UNATTENDED=1`, `DOTFILES_NO_AI_TOOLS=1`, etc. See the
   [customization doc](customization.md) for the full toggle list.
5. **Adding a new tool** -- add the tool config to
   `bootstrap/packages.sh:_tool_config`, add the canonical alias/function to
   `shell/aliases.sh` or `shell/functions.sh`, and update
   `docs/tooling.md`. Tests in `tests/test-packages.sh` will pick up the new
   entry if it follows the existing pattern.

## Testing

The test suite runs via `make test`:

| Suite                          | Focus                                                            |
|--------------------------------|------------------------------------------------------------------|
| `tests/unit-tests.sh`          | Bootstrap helpers, symlink merge, install toggle gating          |
| `tests/test-packages.sh`       | Package installation logic and tool config table                 |
| `tests/test-install.sh`        | End-to-end install integration (symlinks, tools, git config)     |
| `tests/test-consistency.sh`    | Deny-list parity across the six instruction files                |
| `tests/test-gh-repo-policy.sh` | GitHub repo policy CLI                                           |
| `tests/test-ralph.sh`          | Agentic ralph harness                                            |
| `tests/test-dc-audit.sh`       | Devcontainer.json linter rubric                                  |
| `tests/test-settings-drift.sh` | Settings variant drift, deny-list parity, container-variant generation |
| `tests/test-signing.sh`        | SSH signing key detection, devcontainer carve-out, allowed_signers |

Auxiliary scripts in `tests/`:

- `tests/test-security-hook.sh` -- credential blocking via pre-security hook
- `tests/test-emoji-hook.sh`, `tests/test-commit-msg-hook.sh`, `tests/test-functions.sh`
- `tests/validate-dotfiles.sh` -- post-install health check (also exposed as `dotfiles-doctor`)
