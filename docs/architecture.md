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
|   |-- devcontainer-egress.sh # Opt-in iptables egress allowlist (in-container)
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
|-- claude-code/
|   |-- CLAUDE.md              # Global Claude Code instructions
|   |-- settings.json          # Host variant (sandbox.enabled=true)
|   |-- settings.container.json # Container variant (sandbox.enabled=false)
|   |-- statusline.sh          # Status bar (git, context, model)
|   |-- hooks/                 # Security, conventional commits, no-emoji, notify
|   |-- agents/                # PM, architect, implementer, QA, code reviewer
|   +-- commands/              # 16 slash commands (/commit, /pipeline, ...)
|-- codex/
|   |-- AGENTS.md              # Global Codex instructions
|   |-- config.toml            # Host variant (sandbox_mode=workspace-write)
|   |-- config.container.toml  # Container variant (sandbox_mode=danger-full-access)
|   |-- hooks/                 # Pushover notify hook
|   +-- skills/                # Claude-parity workflow skills
|-- copilot/
|   +-- copilot-instructions.md # Global Copilot CLI instructions
|-- config/                    # Starship, ripgrep, bat, bottom, lazygit, yazi
|-- bin/                       # User-facing CLI tools (dc-audit, settings-drift, gh-repo-policy)
|-- agentic/                   # Opt-in agentic harness (separate product)
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
source based on `is_devcontainer()`.

The deployed home-dir instruction files (`~/.claude/CLAUDE.md`,
`~/.codex/AGENTS.md`, `~/.copilot/copilot-instructions.md`) are global
configs. They are user-scope, not project-scope. The dotfiles repo ships a
default set; users can edit the deployed copies for personal preferences.

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
line to copy into `devcontainer.json`. `.devcontainer/example/devcontainer.json`
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

Two complementary linters live in `bin/`:

- [`bin/dc-audit.sh`](../bin/dc-audit.sh) -- security-focused linter for
  `devcontainer.json` files. Rubric-driven (`agentic/devcontainer-rubric.json`):
  image/feature pinning, `--security-opt=no-new-privileges`, resource caps,
  forbidden host credential mounts (unattended profile), `shutdownAction`,
  `updateRemoteUserUID`, `waitFor`. Profiles: `attended` (light safety) and
  `unattended` (hardened). `--fix` applies additive-only fixes (never
  overwrites or removes existing values). Wired into `make lint-devcontainers`.
- [`bin/settings-drift.sh`](../bin/settings-drift.sh) -- variant drift linter.
  Compares `claude-code/settings.json` vs `settings.container.json` on every
  key outside `.sandbox`, and `codex/config.toml` vs `config.container.toml`
  on every key outside `.sandbox_mode`. Wired into `make lint` as a prereq,
  so drift is caught on every CI shellcheck run.

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
   `DOTFILES_DEVCONTAINER_EGRESS=1`, `DOTFILES_EGRESS_EXTRA_HOSTS=docker.io,...`,
   `DOTFILES_NO_AI_TOOLS=1`, etc. See the [customization
   doc](customization.md) for the full toggle list.
5. **Adding a new tool** -- add the tool config to
   `bootstrap/packages.sh:_tool_config`, add the canonical alias/function to
   `shell/aliases.sh` or `shell/functions.sh`, and update
   `docs/tooling.md`. Tests in `tests/test-packages.sh` will pick up the new
   entry if it follows the existing pattern.

## Testing

The test suite (389 tests across 9 suites) runs via `make test`:

| Suite                          | Focus                                                            |
|--------------------------------|------------------------------------------------------------------|
| `tests/unit-tests.sh`          | Bootstrap helpers, symlink merge, install toggle gating          |
| `tests/test-packages.sh`       | Package installation logic and tool config table                 |
| `tests/test-install.sh`        | End-to-end install integration (symlinks, tools, git config)     |
| `tests/test-consistency.sh`    | Deny-list parity across the six instruction files                |
| `tests/test-gh-repo-policy.sh` | GitHub repo policy CLI                                           |
| `tests/test-ralph.sh`          | Agentic ralph harness                                            |
| `tests/test-dc-audit.sh`       | Devcontainer.json linter rubric                                  |
| `tests/test-devcontainer-egress.sh` | Egress script gating + allowlist sanity                     |
| `tests/test-settings-drift.sh` | Host vs container settings variant drift detection               |

Auxiliary scripts in `tests/`:

- `tests/test-security-hook.sh` -- credential blocking via pre-security hook (89 cases)
- `tests/test-emoji-hook.sh`, `tests/test-commit-hook.sh`, `tests/test-functions.sh`
- `tests/validate-dotfiles.sh` -- post-install health check (also exposed as `dotfiles-doctor`)
