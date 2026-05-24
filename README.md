# Dotfiles

A portable developer environment that lays down agentic-coding-ready tooling
on hosts (macOS, Linux, WSL2), VS Code devcontainers, and GitHub Codespaces.

## Philosophy

This repo provides a **developer-specific** environment, not a project-specific
one. The boundary is deliberate:

- Universally useful CLI tools (rg, fd, bat, fzf, delta, ...) belong here -- they
  improve every terminal session regardless of what you're working on.
- Agentic coding tools (Claude Code, Codex CLI, Copilot CLI) belong here -- they're
  part of how the developer works, not tied to any specific project. They get
  the full treatment: installation, configuration, hooks, agents, commands,
  state persistence, and a sandbox posture that adapts per tier.
- Project-dependent executables (gh, docker, kubectl, mise, uv, ...) do **not**
  belong here. Projects bring them in via `devcontainer.json` or `apt-get`;
  this repo supplies the *configuration surface* (aliases, completions, state
  persistence, shell integration) so the developer's workflow is already in
  place when those tools show up.

There are two products in this repo:

1. **Dotfiles + terminal QoL** (default) -- `./install.sh`. What you want on
   any machine.
2. **Agentic harness** (opt-in) -- `./install.sh --with-agentic`. The
   autonomous loop runner (`ralph.sh`), hardened devcontainer profile,
   mitmproxy egress allowlist, and devcontainer linter rubric. Lives under
   `agentic/`; see [`agentic/README.md`](agentic/README.md) for the harness's
   own docs.

## Installation

### VS Code Devcontainers and Codespaces

1. **Fork this repo** on GitHub.
2. **Configure VS Code** (Settings -> "dotfiles"):
   - "Dotfiles: Repository" -> `your-user/dotfiles`
   - "Dotfiles: Install Command" -> `install.sh`
3. Done. Every new devcontainer or Codespace installs automatically.

### Manual

```bash
git clone https://github.com/iggycoloma/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./install.sh
```

Re-running is safe. The installer detects your environment (macOS/Linux,
apt/apk/brew, host/devcontainer) and adapts.

### Prerequisites

Set git identity on your **host machine** -- VS Code copies it into
devcontainers automatically:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

In Codespaces this is automatic from your GitHub profile.

For **SSH commit signing**, the installer auto-detects keys from your agent
(prefers ed25519) or from `~/.ssh/*.pub`. No key? Signing stays off -- no
broken commits. Skip detection entirely with `DOTFILES_NO_SSH_SIGNING=1`.

### Supported platforms

Tested in CI: Ubuntu 20.04/22.04/24.04, Debian 11/12, Alpine latest (musl),
macOS 15/26 (bash and zsh on each), and GitHub Codespaces.

WSL2 is covered by the Linux matrix.

---

## What this gives you (three goals)

### 1. Project-agnostic CLI tooling

A curated set of modern terminal tools installed everywhere, with sensible
defaults and shell integration. Core tools (rg, fd, bat, fzf, jq, delta,
starship, zoxide, eza, sd, scc, yq, watchexec, atuin, ...) plus optional
extras (lazygit, bottom, mise) and configuration-only support for tools your
project brings in (gh, docker, kubectl, direnv, uv).

See [`docs/tooling.md`](docs/tooling.md) for the full inventory plus shell and
git configuration details.

### 2. Customized environment and configuration

Bash and zsh configs, 80+ aliases, 25+ utility functions, three-file git
config (identity stays in `~/.gitconfig`, shared settings come via `[include]`),
starship prompt, ripgrep defaults, optimized zsh startup (deferred zoxide/direnv,
cached compinit), and machine-specific overrides via `*.local` files.

Six installation toggles (`DOTFILES_NO_AI_TOOLS`, `DOTFILES_NO_GIT_HOOKS`, etc.)
let you opt out of pieces you don't want.

See [`docs/customization.md`](docs/customization.md) for the override model,
toggle table, and per-project / per-devcontainer extension patterns.

### 3. Agentic coding support

Native installs of Claude Code and Codex CLI in devcontainers (no Node.js, no
features). Shared guardrails, six-file instruction architecture (project +
global, one per tool), 4 hooks, 5 agents, 16 slash commands for Claude Code,
Claude-parity workflow skills for Codex, and a Pushover notification hook for
both.

A three-tier sandbox posture (below) adapts the security model to the
environment instead of fighting it.

See [`docs/agentic-tooling.md`](docs/agentic-tooling.md) for the tool-by-tool
breakdown and [`docs/sandbox.md`](docs/sandbox.md) for the sandbox specifics.

---

## How it works (three tiers)

The same dotfiles install gives a different shape per tier. The differences
aren't accidental -- each tier is the right boundary for its environment.

| Tier                          | Filesystem isolation       | Network egress                                         | Settings variant            | Persistence                         |
|-------------------------------|----------------------------|--------------------------------------------------------|-----------------------------|-------------------------------------|
| **Host** (macOS/Linux/WSL2)   | Seatbelt or bwrap          | Claude Code `allowedDomains` (kernel-enforced)         | `settings.json` (host)      | Native filesystem                   |
| **Local devcontainer**        | Container is the boundary  | Opt-in iptables allowlist (NET_ADMIN, env-gated)       | `settings.container.json`   | Docker named volume (one mount line)|
| **Codespaces / remote**       | Container is the boundary  | Same iptables script (auto-installs `iptables` binary) | `settings.container.json`   | Platform `/home/vscode` persistence |

Why three tiers instead of one? Trying to run `bwrap` inside devcontainers
produced friction at every step (WSL2 path detection, Docker seccomp,
`CAP_SYS_ADMIN`, an AF_UNIX filter that breaks ssh-agent). The container is
itself a kernel-enforced isolation primitive -- bwrap on top is
defense-in-depth with high maintenance cost. Hosts keep bwrap (where it
works cleanly); containers drop it.

`install.sh` picks the right settings variant by checking `is_devcontainer()`
(env vars + `/.dockerenv` sentinel) and deploys the matching
`settings.container.json` or `settings.json` for Claude Code, plus
`config.container.toml` or `config.toml` for Codex.

See [`docs/sandbox.md`](docs/sandbox.md) for the full sandbox story including
what's gated and what isn't, the SSH-signing nuance on Linux/WSL2 hosts, the
egress allowlist, and the upstream issues (`#44180`, `#10767`, `#29274`) that
shape the design.

---

## Architecture

- **Symlinks on hosts, copies in containers.** Hosts symlink dotfiles config
  into `~/` so edits to the repo immediately reflect in your environment.
  Containers stomp-copy on every install so the dotfiles repo doesn't have to
  exist inside the container.
- **One shared state volume.** A single Docker named volume mount at
  `/home/vscode/.dotfiles-state` (one line in `devcontainer.json`) persists
  Claude Code, Codex, and Copilot CLI state across rebuilds. `install.sh`
  symlinks `~/.claude`, `~/.codex`, `~/.copilot` into subdirectories.
  Codespaces uses platform-level home persistence; no mount line needed.
- **Two settings files per tool.** Host vs container variants for Claude Code
  (`settings.json` / `settings.container.json`) and Codex
  (`config.toml` / `config.container.toml`). A `bin/settings-drift.sh` linter
  in `make lint` enforces sync on every non-sandbox key so variants don't drift.
- **Devcontainer linting.** `bin/dc-audit.sh` checks any `devcontainer.json`
  against a security-focused rubric (image/feature pinning, forbidden
  credential mounts, resource caps, `shutdownAction`, ...) with safe additive
  `--fix` mode. Wired into `make lint-devcontainers`.

For the repository layout, the symlinking/copy strategy, the three-tier state
persistence implementation, and a "how to modify this for your own use"
walkthrough, see [`docs/architecture.md`](docs/architecture.md).

---

## Customization

Quick reference:

| Override file       | Purpose                                                     |
|---------------------|-------------------------------------------------------------|
| `~/.bashrc.local`   | Bash-specific overrides                                     |
| `~/.zshrc.local`    | Zsh-specific overrides                                      |
| `~/.exports.local`  | Environment variables (PATH additions, API keys)            |
| `~/.aliases.local`  | Extra aliases                                               |
| `~/.functions.local`| Extra functions                                             |

| Toggle (set before install)             | Effect                                          |
|-----------------------------------------|-------------------------------------------------|
| `DOTFILES_NO_AI_TOOLS=1`                | Skip Claude Code, Codex CLI, ast-grep, difft, configs |
| `DOTFILES_NO_ATUIN=1`                   | Skip atuin shell history                        |
| `DOTFILES_NO_GIT_HOOKS=1`               | Skip global git hooks                           |
| `DOTFILES_NO_STATE_PERSISTENCE=1`       | Skip state persistence wiring                   |
| `DOTFILES_NO_SSH_SIGNING=1`             | Skip SSH commit signing auto-detection          |
| `DOTFILES_OPINIONATED_ALIASES=1`        | Shadow `grep` with rg and `find` with fd       |
| `DOTFILES_INSTALL_AGENTIC=1`            | Deploy the agentic harness to `~/.agentic/`     |
| `DOTFILES_DEVCONTAINER_EGRESS=1`        | Install the iptables egress allowlist (needs NET_ADMIN) |
| `DOTFILES_EGRESS_EXTRA_HOSTS=a,b,c`     | Add hosts to the egress allowlist               |

For the full table, opinionated-alias details, per-project Claude/Codex
overrides via `settings.local.json`, devcontainer `remoteEnv` patterns, and
shell profiling, see [`docs/customization.md`](docs/customization.md).

---

## Spinoffs (future direction)

A few pieces are good candidates to spin out of this repo once they earn it:

- **State persistence as a devcontainer Feature.** Today users add one volume
  mount line to `devcontainer.json`. Publishing a Feature on GHCR could let
  the mount + install command be declared in a single `features` entry.
- **Agentic harness as a standalone package.** The `agentic/` subtree is
  already opt-in (`./install.sh --with-agentic`) and self-contained; an
  independent distribution would let non-dotfiles users adopt it.
- **Workspace-local state.** Evaluated and removed for security reasons (auth
  tokens in the project tree are a footgun); the analysis is preserved at
  [`docs/future-workspace-local-state.md`](docs/future-workspace-local-state.md).

See [`docs/spinoffs.md`](docs/spinoffs.md) for the rationale on each.

---

## Diagnostics and testing

```bash
dotfiles-doctor          # Health check: symlinks, tools, git config, signing
make lint                # shellcheck + bin/settings-drift.sh
make test                # Full suite (unit, packages, integration, etc.)
make test-integration    # Just the install integration test
ZSH_PROFILE=1 zsh -i -c exit   # Profile zsh startup (zprof output)
```

Currently 389 tests across 9 suites. Test files live in `tests/`; see
[`docs/architecture.md`](docs/architecture.md#testing) for what each covers.

---

## Documentation map

- [`docs/architecture.md`](docs/architecture.md) -- repo layout, scope boundary,
  symlink/copy strategy, state persistence, devcontainer linting, modifying
  for your own use.
- [`docs/tooling.md`](docs/tooling.md) -- full CLI inventory, shell config,
  git config.
- [`docs/agentic-tooling.md`](docs/agentic-tooling.md) -- the six-file
  instruction architecture, hooks/agents/commands, per-tier behavior.
- [`docs/sandbox.md`](docs/sandbox.md) -- three-tier sandbox posture in full
  detail.
- [`docs/customization.md`](docs/customization.md) -- override files,
  toggles, per-project extensions, environment-variable reference.
- [`docs/spinoffs.md`](docs/spinoffs.md) -- forward-looking directions.
- [`agentic/README.md`](agentic/README.md) -- the agentic harness's own docs
  (`ralph.sh`, unattended profile, `dc-audit.sh`).

## Resources

- [Dotfiles Guide](https://dotfiles.github.io/)
- [AGENTS.md Standard](https://agents.md/)
- [Configure the sandboxed Bash tool (Claude Code docs)](https://code.claude.com/docs/en/sandboxing)
- [Dev Container Features reference](https://containers.dev/implementors/features/)
- [VS Code Dotfiles Guide](https://code.visualstudio.com/docs/remote/containers#_personalizing-with-dotfile-repositories)

## License

MIT.
