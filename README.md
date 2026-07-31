# Dotfiles

A portable developer environment for hosts (macOS, Linux, WSL2), VS Code
devcontainers, and GitHub Codespaces -- with a tier-aware agentic coding
setup baked in.

## Philosophy and scope

This repo provides a **developer-specific** environment, not a
project-specific one. The boundary is deliberate:

- **Universally useful CLI tools** (rg, fd, bat, fzf, delta, ...) belong here.
  They improve every terminal session regardless of what you're working on.
- **Customization and shell config** (aliases, functions, exports,
  completions, git settings) belong here. A developer's preferences should
  be ready on any machine.
- **Agentic coding tools** (Claude Code, Codex CLI, Copilot CLI) belong here.
  They're part of how the developer works, not tied to any specific project.
  They get the full treatment: installation, configuration, hooks, agents,
  commands, state persistence, and a sandbox posture that adapts per
  environment.
- **Project-dependent executables** (gh, docker, kubectl, mise, uv, ...) do
  **not** belong here. Projects bring them in via `devcontainer.json` or
  `apt-get`; this repo supplies the *configuration surface* (aliases,
  completions, state persistence, shell integration) so the developer's
  workflow is already in place when those tools show up.

Two products in this repo:

1. **Dotfiles + terminal QoL** (default) -- `./install.sh`. What you want on
   every machine. Includes the agentic coding *tools* (Claude Code, Codex
   CLI, Copilot CLI) with their configs, hooks, agents, and commands.
2. **Unattended coding harness** (opt-in) --
   `./install.sh --with-unattended`. The configuration for running Claude
   Code *without a human supervising each step*: the `ralph.sh` autonomous
   loop runner, the hardened devcontainer profile (`--cap-drop=ALL` +
   mitmproxy egress allowlist), and the devcontainer linter rubric.
   Lives under [`unattended/`](unattended/README.md). "Agentic" alone
   means the interactive tools (above); "unattended harness" means
   specifically this opt-in subtree.

## Where it runs (three tiers)

This repo treats three environments as first-class targets. The install
adapts automatically; the rest of the README uses these names as
shorthand.

| Tier | Definition |
|------|-----------|
| **Host** | Your laptop or workstation -- macOS, Linux, or WSL2. The dotfiles repo lives at `~/.dotfiles`; configs are symlinked into `~/`. |
| **Local devcontainer** | VS Code devcontainer running on your host's Docker. The dotfiles install runs inside the container via `postCreateCommand`. |
| **Codespaces / remote container** | GitHub Codespaces or any remote-container setup. Same install path as local devcontainers, with platform-level persistence handling. |

The same dotfiles install behaves differently per tier: where configs are
sourced from (host symlinks vs in-container copies), which settings variant
to deploy (host sandbox vs container-as-boundary), how state persists
(filesystem vs volume vs platform). Detection lives in
`bootstrap/detect.sh:is_devcontainer` (env vars + `/.dockerenv` sentinel).

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

## What you get

Three goals, in the order the developer encounters them. Each section has
the highlights inline; deep details live in a focused doc.

### Project-agnostic CLI tooling

A curated set of modern terminal tools, installed everywhere with sensible
defaults and shell integration. On Linux from GitHub releases
(checksum-verified, musl-static where it matters); on macOS via Homebrew.

| Category                | Tools                                                                                  |
|-------------------------|----------------------------------------------------------------------------------------|
| Search / navigate       | fzf, ripgrep (rg), fd, zoxide, eza, yazi                                               |
| View / diff             | bat, git-delta, scc, dust, duf, procs                                                  |
| Edit / process          | jq, yq, sd, ast-grep (sg), difftastic (difft)                                          |
| Shell / prompt          | starship, atuin, carapace, watchexec, hyperfine                                        |
| Quality                 | shellcheck, gitleaks                                                                   |
| Optional (hosts)        | lazygit, bottom (btm), mise                                                            |
| Config-only (project brings the tool) | gh, glab, docker, kubectl, direnv, uv, xh                                |

Skip the AI-adjacent tools (ast-grep, difftastic) with
`DOTFILES_NO_AI_TOOLS=1`; skip atuin with `DOTFILES_NO_ATUIN=1`.

See [`docs/tooling.md`](docs/tooling.md) for the full inventory, what each
tool replaces, and the rationale behind the "config-only" line for
project-dependent tools.

### Customized environment and configuration

Shell, git, and tool configuration that travels with you:

- **Shell configs** -- bash and zsh with optimized startup (deferred
  zoxide/direnv, cached `compinit`), 80+ aliases, 25+ utility functions
  (`mkcd`, `extract`, `killport`, `gcof`, `glf`, `dotfiles-doctor`,
  `serve`, smart `cat` that uses bat in terminals and plain cat in pipes).
- **Git** -- three-file model: your identity stays in `~/.gitconfig`,
  shared settings (delta, 44 aliases, hooks) come via an `[include]` in
  `~/.config/git/config`. Conventional commits and gitleaks pre-commit
  enforced globally via `core.hooksPath`.
- **Prompt + defaults** -- starship two-line prompt with language/docker
  status, ripgrep defaults (follow symlinks, hidden files, exclude .git).

#### Override files (gitignored)

| File                   | Purpose                                          |
|------------------------|--------------------------------------------------|
| `~/.bashrc.local`      | Bash-specific overrides                          |
| `~/.zshrc.local`       | Zsh-specific overrides                           |
| `~/.exports.local`     | Environment variables (PATH additions, API keys) |
| `~/.aliases.local`     | Extra aliases                                    |
| `~/.functions.local`   | Extra functions                                  |

#### Installation toggles

Set before running `install.sh`, or in `~/.exports.local`, or in your
devcontainer's `remoteEnv`:

| Toggle                                  | Effect                                                                  |
|-----------------------------------------|-------------------------------------------------------------------------|
| `DOTFILES_NO_AI_TOOLS=1`                | Skip Claude Code, Codex CLI, ast-grep, difftastic, all AI configs       |
| `DOTFILES_NO_ATUIN=1`                   | Skip atuin shell history                                                |
| `DOTFILES_NO_GIT_HOOKS=1`               | Skip global git hooks (conventional commits, gitleaks pre-commit)       |
| `DOTFILES_NO_STATE_PERSISTENCE=1`       | Skip state persistence wiring                                           |
| `DOTFILES_NO_SSH_SIGNING=1`             | Skip SSH commit signing auto-detection                                  |
| `DOTFILES_OPINIONATED_ALIASES=1`        | Shadow `grep` with rg and `find` with fd                                |
| `DOTFILES_INSTALL_UNATTENDED=1`         | Deploy the opt-in unattended coding harness to `~/.unattended/`                      |

See [`docs/customization.md`](docs/customization.md) for opinionated-alias
details, per-project Claude/Codex overrides via `settings.local.json`,
per-devcontainer `remoteEnv` patterns, diagnostics, and the full env-var
reference.

### Agentic coding support

Native installs of Claude Code and Codex CLI on hosts, devcontainers, and
Codespaces (no Node.js, no devcontainer features). Install-once, like every
other tool -- run `claude update` or `codex update` to move one forward.
Shared guardrails across a six-file instruction
architecture (project-scope `AGENTS.md` + `CLAUDE.md` +
`.github/copilot-instructions.md`, plus global-scope `claude-code/CLAUDE.md`
+ `codex/AGENTS.md` + `copilot/copilot-instructions.md`).

| Component                       | Count | What it does                                                                                          |
|---------------------------------|-------|-------------------------------------------------------------------------------------------------------|
| Settings variants per tool      | 2     | Host (`settings.json` / `config.toml`) and container (`settings.container.json` / `config.container.toml`) flavors |
| Hooks (Claude Code)             | 4     | Credential blocking, conventional commits enforcement, no-emoji blocker, Pushover idle notification   |
| Agents (Claude Code)            | 5     | PM spec, architect, implementer-tester, QA reviewer, code reviewer (wired into `/pipeline`)           |
| Commands (Claude Code)          | 16    | `/commit`, `/pr-create`, `/review-pr`, `/debug`, `/test`, `/refactor`, `/security-audit`, `/pipeline` |
| Skills (Codex)                  | n/a   | Claude-parity workflow skills mapping user intent                                                     |

The **4-stage pipeline** (`/pipeline`) runs PM spec -> architecture review
-> implementation + tests -> QA review, with user checkpoints between
stages.

Sandbox is **tier-aware** (see [Sandbox posture](#sandbox-posture) below):

- **Host**: full Claude Code Bash sandbox (Seatbelt on macOS, bwrap on
  Linux/WSL2), `allowedDomains` enforced kernel-level via a host proxy.
- **Devcontainer / Codespaces**: container *is* the sandbox boundary;
  OS-level sandbox disabled to avoid leaky abstractions. Validate the
  container spec with `bin/dc-audit.sh`; the opt-in `unattended/` harness
  ships a hardened profile with mitmproxy egress when you need a
  per-hostname allowlist.

WebFetch and WebSearch are **not** gated by `allowedDomains` -- only Bash
subprocesses are -- so research is unaffected by a narrow allowlist.

Skip the whole agentic stack with `DOTFILES_NO_AI_TOOLS=1`.

See [`docs/agentic-tooling.md`](docs/agentic-tooling.md) for the
tool-by-tool breakdown (hooks deep-dive, MCP posture, per-tier behavior)
and [`docs/sandbox.md`](docs/sandbox.md) for the full sandbox story.

---

## How it works

### Architecture

- **Symlinks on hosts, copies in containers.** Hosts symlink dotfiles
  config into `~/` so edits to the repo immediately reflect in your
  environment. Containers stomp-copy on every install so the dotfiles repo
  doesn't have to exist inside the container.
- **One shared state volume.** A single Docker named volume mount line --
  `source=${devcontainerId}-state,target=/home/vscode/.dotfiles-state,type=volume`
  -- persists Claude Code, Codex, and Copilot CLI state across rebuilds.
  `install.sh` symlinks `~/.claude`, `~/.codex`, `~/.copilot` into
  subdirectories of the volume. Codespaces uses platform-level home
  persistence; no mount line needed.
- **Two settings files per tool.** Host vs container variants for Claude
  Code (`settings.json` / `settings.container.json`) and Codex
  (`config.toml` / `config.container.toml`). The Claude container variant is
  generated by `bin/sync-settings.sh` (`make sync-settings`), so it cannot
  drift; the Codex pair is hand-maintained and `bin/settings-drift.sh` in
  `make lint` enforces sync on every non-sandbox key.
- **Devcontainer linting.** `bin/dc-audit.sh` checks any
  `devcontainer.json` against a security-focused rubric (image/feature
  pinning, forbidden credential mounts, resource caps, `shutdownAction`,
  ...) with safe additive `--fix` mode. Wired into
  `make lint-devcontainers`.

See [`docs/architecture.md`](docs/architecture.md) for the repository
layout, the detection logic, the three-tier state-persistence
implementation, and a "how to modify this for your own use" walkthrough.

### Sandbox posture

| Tier                          | Filesystem isolation       | Network egress                                         | Settings variant            | Persistence                         |
|-------------------------------|----------------------------|--------------------------------------------------------|-----------------------------|-------------------------------------|
| **Host** (macOS/Linux/WSL2)   | Seatbelt or bwrap          | Claude Code `allowedDomains` (kernel-enforced)         | `settings.json` (host)      | Native filesystem                   |
| **Local devcontainer**        | Container is the boundary  | Unrestricted by default; `bin/dc-audit.sh` lints the spec for risky mounts/caps | `settings.container.json`   | Docker named volume (one mount line)|
| **Codespaces / remote**       | Container is the boundary  | Same as local devcontainer                             | `settings.container.json`   | Platform `/home/vscode` persistence |

Why three tiers instead of one? Trying to run `bwrap` inside devcontainers
produced friction at every step (WSL2 path detection, Docker seccomp,
`CAP_SYS_ADMIN`, an AF_UNIX filter that breaks ssh-agent). The container
is itself a kernel-enforced isolation primitive -- bwrap on top is
defense-in-depth with high maintenance cost. Hosts keep bwrap (where it
works cleanly); containers drop it.

See [`docs/sandbox.md`](docs/sandbox.md) for what's gated and what isn't
(WebFetch / WebSearch are intentionally exempt), the SSH-signing nuance on
Linux/WSL2 hosts, and the upstream Claude Code issues (#44180, #10767,
#29274) that shape the design. Egress enforcement for unattended runs lives
in `unattended/` (mitmproxy + hostname allowlist).

---

## Spinoffs (future direction)

A few pieces are good candidates to spin out of this repo once they earn it:

- **State persistence as a devcontainer Feature** -- publish on GHCR so
  projects can declare the mount + install command in a single `features`
  entry instead of a mount line.
- **Unattended coding harness as a standalone package** -- the
  `unattended/` subtree (autonomous loop runner, hardened devcontainer
  profile, mitmproxy allowlist) is already opt-in and self-contained;
  could distribute independently as an unattended-Claude-Code package.
- **Workspace-local state** -- evaluated and removed for security reasons
  (auth tokens in the project tree are a footgun); analysis preserved at
  [`docs/future-workspace-local-state.md`](docs/future-workspace-local-state.md).
- **Shared instruction-file partials** -- the cross-file dup of
  Guardrails / Preferred CLI Tools / MCP across six files could fold into
  templating at deploy time.

See [`docs/spinoffs.md`](docs/spinoffs.md) for the rationale on each.

---

## Diagnostics and testing

```bash
dotfiles-doctor                # Health check: symlinks, tools, git config, signing
make lint                      # shellcheck + settings sync/drift + devcontainer audit
make sync-settings             # Regenerate claude-code/settings.container.json
make test                      # Full suite (unit, packages, integration, drift, dc-audit, ...)
make test-integration          # Just the install integration test
ZSH_PROFILE=1 zsh -i -c exit   # Profile zsh startup (zprof output)
```

Currently 389 tests across 9 suites. Test files live in `tests/`; see
[`docs/architecture.md#testing`](docs/architecture.md#testing) for what
each suite covers.

---

## Documentation map

- [`docs/architecture.md`](docs/architecture.md) -- repo layout, scope
  boundary, symlink/copy strategy, state persistence, devcontainer
  linting, modifying for your own use.
- [`docs/tooling.md`](docs/tooling.md) -- full CLI inventory, shell
  config, three-file git config.
- [`docs/agentic-tooling.md`](docs/agentic-tooling.md) -- six-file
  instruction architecture, hooks / agents / commands, MCP posture,
  per-tier behavior.
- [`docs/sandbox.md`](docs/sandbox.md) -- three-tier sandbox posture in
  full detail.
- [`docs/customization.md`](docs/customization.md) -- override files,
  toggles, per-project extensions, environment-variable reference.
- [`docs/spinoffs.md`](docs/spinoffs.md) -- forward-looking directions.
- [`unattended/README.md`](unattended/README.md) -- the unattended coding
  harness's own docs (`ralph.sh`, hardened devcontainer profile,
  `dc-audit.sh`).

## Resources

- [Dotfiles Guide](https://dotfiles.github.io/)
- [AGENTS.md Standard](https://agents.md/)
- [Configure the sandboxed Bash tool (Claude Code docs)](https://code.claude.com/docs/en/sandboxing)
- [Dev Container Features reference](https://containers.dev/implementors/features/)
- [VS Code Dotfiles Guide](https://code.visualstudio.com/docs/remote/containers#_personalizing-with-dotfile-repositories)

## License

MIT.
