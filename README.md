# Dotfiles

Portable developer environment that lays down a productive, agentic coding setup on local hosts (macOS/Linux), VS Code devcontainers, and GitHub Codespaces.

## Quick Start

### VS Code Devcontainers / Codespaces

1. **Fork this repository** on GitHub
2. **Configure VS Code** (Settings > search "dotfiles"):
   - Set "Dotfiles: Repository" to `your-username/dotfiles`
   - Set "Dotfiles: Install Command" to `install.sh`
3. **Done.** Your dotfiles install automatically in every new devcontainer and Codespace.

### Manual Installation

```bash
git clone https://github.com/iggycoloma/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./install.sh
```

The installer detects your environment (macOS/Linux, apt/apk/brew, devcontainer/local) and adapts automatically. It is safe to re-run.

### Prerequisites

Set your git identity on your host machine (this is what VS Code copies into devcontainers):

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

For **Codespaces**, your GitHub profile name and email are used automatically -- no host config needed.

For **SSH commit signing**, the installer auto-detects SSH keys from your agent (prefers ed25519). If you have a key loaded (`ssh-add -L`), signing is enabled automatically. No key? Signing stays disabled -- no broken commits. You can skip detection entirely with `DOTFILES_NO_SSH_SIGNING=1`.

---

## Design Philosophy

This repo provides a **developer-specific** environment, not a project-specific one.

| Responsibility | Belongs to |
|---|---|
| Install universally useful shell tools (rg, fd, bat, fzf, etc.) | This repo |
| Deeply integrate tools used everywhere (Claude Code, Codex CLI) | This repo |
| Supply preferences for project-dependent tools (aliases, completions, config, state persistence) | This repo |
| Install project-dependent executables (gh, docker, kubectl, etc.) | Project devcontainer.json |

**Developer tools** are installed by this repo because they improve every terminal session regardless of what you're working on -- fast search, syntax highlighting, modern git diffs, smart directory jumping, shell history.

**Agentic coding tools** (Claude Code, Codex CLI) are installed by this repo because they're part of how the developer works, not tied to any specific project. They get full treatment: installation, configuration, hooks, agents, commands, and state persistence.

**Project-dependent tools** (gh, docker, kubectl, mise, uv, etc.) are NOT installed by this repo. Projects install their own tooling via `devcontainer.json` or similar. This repo supplies the *configuration surface* -- aliases, completions, state persistence, shell integration -- so when a project brings in a tool, the developer's preferred workflow is already there waiting. An alias for a missing tool is harmless ("command not found" is fine).

### Supported Platforms

Tested in CI and fully supported:

- **Ubuntu** 20.04, 22.04, 24.04 (bash and zsh)
- **Debian** 11 (Bullseye), 12 (Bookworm) (bash and zsh)
- **Alpine** latest (musl libc)
- **macOS** 15, 26 (bash and zsh)
- **GitHub Codespaces** (Ubuntu-based devcontainer)

WSL2 runs Ubuntu/Debian underneath and is covered by the Linux matrix.

---

## What's Included

### CLI Tools

On Linux, most tools come from GitHub releases with checksum verification (musl-static builds for portability). On macOS, Homebrew handles everything.

**Core tools** -- installed everywhere, improve every terminal session:

| Tool | Purpose |
|------|---------|
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder for files, history, and more |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (rg) | Fast regex search across files |
| [fd](https://github.com/sharkdp/fd) | Fast file finder |
| [bat](https://github.com/sharkdp/bat) | Cat with syntax highlighting |
| [jq](https://github.com/jqlang/jq) | JSON processor |
| [starship](https://starship.rs/) | Cross-shell prompt with git status |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smart directory jumping (replaces cd) |
| [eza](https://github.com/eza-community/eza) | Modern ls replacement with git integration |
| [git-delta](https://github.com/dandavison/delta) | Beautiful, syntax-highlighted git diffs |
| [sd](https://github.com/chmln/sd) | Find-and-replace (modern sed, PCRE regex) |
| [scc](https://github.com/boyter/scc) | Fast code statistics (LOC, complexity) |
| [yq](https://github.com/mikefarah/yq) | YAML/TOML/XML editor (preserves comments) |
| [watchexec](https://github.com/watchexec/watchexec) | File watcher for auto-test/rebuild |
| [gitleaks](https://github.com/gitleaks/gitleaks) | Secret scanner (pre-commit hook) |
| [shellcheck](https://github.com/koalaman/shellcheck) | Shell script linter |
| [atuin](https://github.com/atuinsh/atuin) | Shell history with SQLite and context search |
| [duf](https://github.com/muesli/duf) | Modern disk free utility |
| [dust](https://github.com/bootandy/dust) | Intuitive disk usage (modern du) |
| [procs](https://github.com/dalance/procs) | Modern process viewer with color and search |
| [hyperfine](https://github.com/sharkdp/hyperfine) | Command-line benchmarking tool |
| [yazi](https://github.com/sxyazi/yazi) | Terminal file manager with async I/O and preview |

**Agentic tools** -- installed in devcontainers, deeply configured:

| Tool | Purpose |
|------|---------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | AI coding assistant CLI |
| [Codex CLI](https://github.com/openai/codex) | AI coding assistant CLI |
| [ast-grep](https://ast-grep.github.io/) (sg) | Structural code search by AST |
| [difftastic](https://github.com/Wilfred/difftastic) (difft) | AST-aware file diff (ignores formatting) |

**Optional tools** -- installed on hosts, skipped in CI/lightweight environments:

| Tool | Purpose |
|------|---------|
| [lazygit](https://github.com/jesseduffield/lazygit) | Terminal UI for git |
| [bottom](https://github.com/ClementTsang/bottom) (btm) | System monitor |

**Developer preferences** -- NOT installed, but aliases, completions, and config are supplied:

| Tool | What this repo provides |
|------|------------------------|
| [gh](https://cli.github.com/) | Aliases, completions, `~/.config/gh` state persistence, `ghpr` function |
| [docker](https://www.docker.com/) | Aliases (`d`, `dc`, `dps`, `di`, `dex`), functions (`dclean`, `dkill`, `dlogs`) |
| [kubectl](https://kubernetes.io/) | Aliases (`k`, `kgp`, `kgs`, `kgd`), completions |
| [direnv](https://direnv.net/) | Shell activation (deferred on zsh for performance) |

### Shell Configuration

**Aliases** (`shell/aliases.sh`): 80+ aliases for git, docker, kubernetes, python, navigation, and modern tool replacements. Core utilities like `grep` and `find` are not shadowed by default -- set `DOTFILES_OPINIONATED_ALIASES=1` to enable.

**Functions** (`shell/functions.sh`): 25+ utility functions including `mkcd`, `extract`, `killport`, `gcof` (fzf branch picker), `glf` (fzf git log), `dotfiles-doctor` (installation diagnostic), `serve` (quick HTTP server), `y` (yazi with cd-on-exit), docker helpers, and smart `cat` (uses bat in terminal, plain cat in pipes).

**Environment** (`shell/exports.sh`): XDG base directory compliance, large history (100K entries), fzf with TokyoNight theme, bat/eza/ripgrep themes, editor preference chain (nvim > vim > vi), Docker BuildKit enabled.

**Local overrides** -- create any of these to add machine-specific config (gitignored):

```
~/.bashrc.local      ~/.zshrc.local
~/.exports.local     ~/.aliases.local     ~/.functions.local
```

**Performance** -- zsh startup is optimized:
- Completion cache (`compinit`) rebuilds once per day, not every shell start
- zoxide and direnv initialize on first prompt (deferred via `precmd`), not during startup
- Profile startup time with `ZSH_PROFILE=1 zsh -i -c exit` (uses `zprof`)
- CI builds log per-component timing automatically

### Git Configuration

Git uses three config files, each with a distinct role:

| File | Purpose | Managed by |
|------|---------|------------|
| `~/.gitconfig` | User identity (name, email, signing key) | You (or VS Code/Codespaces) |
| `~/.config/git/config` | XDG config with `[include]` pointing to dotfiles settings | install.sh |
| `git/.gitconfig` (this repo) | Shared settings: delta, aliases, hooks, merge, rebase, etc. | This repo |

**How it works:** `install.sh` prepends an `[include]` directive to `~/.config/git/config` that pulls in `git/.gitconfig` from this repo. Git reads configs in order (`~/.gitconfig` first, then `~/.config/git/config`), and later values override earlier ones. This means your personal identity in `~/.gitconfig` is never touched, while dotfiles settings (delta, aliases, hooks) load via the include.

The XDG config file (`~/.config/git/config`) is a real file, not a symlink, so `git config --global` writes go there safely without dirtying the dotfiles repo. If the installer finds a legacy symlink from an older version, it migrates automatically.

**Delta integration** -- syntax-highlighted diffs with line numbers, side-by-side optional, OneHalfDark theme.

**44 git aliases** -- shortcuts for every common operation (`gs` = status, `gl` = log graph, `gd` = diff, `gpf` = push --force-with-lease, etc.). Full list: `git aliases`.

**Conventional commits** -- enforced globally via `commit-msg` hook:
- Required format: `type(scope): description` (feat, fix, refactor, docs, test, etc.)
- Minimum 10-character subject
- Blocks AI tool attribution and `Co-Authored-By` lines
- Blocks emoji characters in commit messages
- Merge commits pass through unchanged
- Per-repo customization via `.git/hooks/commit-msg.local`

**SSH commit signing** -- the installer auto-detects SSH keys from your agent (prefers ed25519) or `~/.ssh/id_ed25519.pub`. When a key is found, `commit.gpgsign` is enabled and an `allowed_signers` file is created. No key? Signing stays disabled -- no broken commits.

**Secret scanning** -- gitleaks runs as a global `pre-commit` hook, scanning staged changes for API keys, passwords, and tokens. Silently passes if gitleaks is not installed. Per-repo hooks via `.git/hooks/pre-commit.local`.

### Agentic Coding Tools

This repo configures two AI coding assistants with shared guardrails and workflows. In devcontainers, Claude Code and Codex CLI are installed automatically as native binaries -- no devcontainer features or Node.js required. Disable with `DOTFILES_NO_AI_TOOLS=1`.

**Architecture:**

| File | Scope | Read by | Purpose |
|------|-------|---------|---------|
| `AGENTS.md` (root) | This repo | All AI tools | Per-repo shared instructions (guardrails, tools, quality gates) |
| `CLAUDE.md` (root) | This repo | Claude Code | Per-repo Claude-specific instructions |
| `.github/copilot-instructions.md` | This repo | GitHub Copilot | Per-repo Copilot instructions |
| `claude-code/CLAUDE.md` | Global | Claude Code | Global Claude Code instructions (deployed to `~/.claude/`) |
| `codex/AGENTS.md` | Global | Codex CLI | Global Codex instructions (deployed to `~/.codex/`) |

Project-specific instructions (quality gates, installation toggles, security model) live in root files. Global files contain only preferences and guardrails that apply across all repositories.

**Shared guardrails** (enforced in all three files):
- No emoji in code, docs, or commits
- Conventional commits; no AI attribution or Co-Authored-By
- Never access credential files or directories (~50 blocked patterns)
- Prefer modern CLI tools (rg, fd, sg, difft, sd, bat, scc, yq)
- `make lint` (shellcheck) required before merging; CI enforces this

**Claude Code** (`claude-code/`):

| Component | Count | Purpose |
|-----------|-------|---------|
| Hooks | 4 | Security (credential blocking), conventional commits, no-emoji, idle notification |
| Agents | 5 | PM spec writer, architect reviewer, implementer-tester, QA reviewer, code reviewer |
| Commands | 16 | commit, pr-create, review-pr, debug, test, refactor, security-audit, pipeline, etc. |
| Status line | 1 | Git branch/status, context usage bar, model info |

The **4-stage pipeline** (`/pipeline`) runs: PM Spec -> Architecture Review -> Implementation + Tests -> QA Review, with user checkpoints between stages.

Permission model: explicit allow-list of ~70 bash commands, deny-list of ~35 credential patterns, `pre-security.sh` hook validates every file read/write/edit at runtime.

**Codex CLI** (`codex/`):
- `AGENTS.md` with Claude-parity guardrails and workflow intents
- `skills/claude-parity/` maps user intent to Claude Code-style workflows
- `hooks/notify.sh` sends Pushover notifications when idle
- Shell aliases: `cx` (codex), `cxe` (codex exec), `cxr` (codex review --uncommitted)

### Prompt and Tool Configuration

**Starship** (`config/starship.toml`): Two-line prompt showing username, directory (truncated to repo), git branch with status indicators (ahead/behind/conflicts/stashed/modified/staged), language versions (Python, Node, Rust, Go, Java, Ruby), Docker context, and command duration.

**Ripgrep** (`config/ripgrep/config`): Follows symlinks, searches hidden files, excludes `.git`, smart-case matching, sorted by path, colored output.

---

## Devcontainer Support

These dotfiles automatically adapt to devcontainers and Codespaces. Claude Code and Codex CLI are installed as native binaries -- no devcontainer features or Node.js required.

### How It Works

The installer detects devcontainer environments and automatically:
- Installs Claude Code and Codex CLI as native binaries
- Installs all configured CLI tools (core + AI-adjacent)
- Deploys AI tool configs (~/.claude, ~/.codex) with fresh copies from dotfiles
- Detects the best state persistence tier (no configuration needed)

**State persistence** is automatic via a tiered fallback:

| Tier | Environment | Storage location | Persists across rebuild? |
|------|-------------|-----------------|:---:|
| Volume | Local devcontainer (with mount) | Docker named volume | Yes |
| Codespaces | GitHub Codespaces | `.persistedshare/dotfiles-state/` | Yes (automatic) |
| Ephemeral | Fallback | `~/.dotfiles-state/` | No |

In Codespaces, state persistence is automatic. For local devcontainers, add a volume mount to your `devcontainer.json`:

```json
"mounts": ["source=${devcontainerId}-state,target=/home/vscode/.dotfiles-state,type=volume"]
```

If no volume mount is detected, the installer logs this line so you can copy-paste it into your `devcontainer.json`. See `.devcontainer/example/` for a complete example.

**Why not workspace-local?** We evaluated storing state in the project directory (`<project>/.dotfiles-state/`, gitignored) to avoid the volume mount requirement for local devcontainers. This was removed because it places auth tokens (Claude Code, Codex, GitHub CLI) inside the project tree -- a security risk for backups, archive uploads, Docker `COPY` commands, and workspace scanners. Even with `.gitignore` and `.git/info/exclude` protection, the blast radius of accidental exposure is too high. See `docs/future-workspace-local-state.md` for the full analysis.

**What persists**: credentials, auth tokens, shell history, sessions, plans, caches.

**What refreshes** (copied from dotfiles every boot): settings.json, CLAUDE.md, AGENTS.md, hooks, agents, commands, skills.

### Git in Devcontainers

Git identity (name/email) must be present in the container for commits to work. How it gets there depends on the environment:

**Local devcontainers (VS Code Remote - Containers):**
- VS Code copies your host `~/.gitconfig` into the container at startup, bringing your identity (name, email, signing key) along automatically
- The installer then prepends the `[include]` for dotfiles settings (delta, aliases, hooks) into `~/.config/git/config`
- Result: your identity from the host + dotfiles settings from this repo

**GitHub Codespaces:**
- Codespaces configures `git config --system user.name` and `user.email` from your GitHub profile automatically
- There is no host `~/.gitconfig` to copy -- identity comes from Codespaces infrastructure
- The installer adds the `[include]` the same way as local devcontainers

**In both cases:**
- SSH agent is forwarded by VS Code -- commit signing works without distributing keys
- `git config --global` writes go to `~/.config/git/config` (the XDG file), not the dotfiles repo
- The three-file git config model (see Git Configuration above) applies identically

---

## Repository Structure

```
dotfiles/
|-- install.sh                 # Main installer (detects env, orchestrates everything)
|-- Makefile                   # make lint (shellcheck), make test
|-- AGENTS.md                  # Shared AI tool instructions (per-repo, all tools)
|-- CLAUDE.md                  # Claude Code project instructions (per-repo)
|-- bootstrap/
|   |-- detect.sh              # Environment/OS/package manager detection
|   |-- logging.sh             # Colored log functions
|   |-- packages.sh            # Tool installation (apt/apk/brew + GitHub releases)
|   |-- symlinks.sh            # Symlink creation with backup and devcontainer support
|   |-- completions.sh         # Shell completion setup (bash + zsh + zinit)
|-- shell/
|   |-- .bashrc, .bash_profile # Bash configuration
|   |-- .zshrc, .zprofile      # Zsh configuration (compinit caching, zprof support)
|   |-- aliases.sh             # 80+ command aliases
|   |-- functions.sh           # 25+ utility functions (including dotfiles-doctor)
|   |-- exports.sh             # Environment variables (XDG, editor, themes)
|   +-- completion.sh          # Tool init (fzf, zoxide, atuin, direnv) with lazy-loading
|-- git/
|   |-- .gitconfig             # Git settings (delta, aliases, SSH signing, hooks path)
|   |-- .gitignore_global      # Global gitignore
|   |-- .gitmessage            # Conventional commit template
|   +-- hooks/
|       |-- commit-msg         # Conventional commits enforcement (global)
|       +-- pre-commit         # Gitleaks secret scanning (global)
|-- claude-code/
|   |-- CLAUDE.md              # Global Claude Code instructions
|   |-- settings.json          # Permissions, hooks, status line config
|   |-- statusline.sh          # Status bar (git, context usage, model)
|   |-- hooks/                 # 4 hooks (security, commits, emoji, notify)
|   |-- agents/                # 5 agents (PM, architect, implementer, QA, reviewer)
|   +-- commands/              # 16 slash commands (/commit, /pipeline, /debug, etc.)
|-- codex/
|   |-- AGENTS.md              # Global Codex instructions
|   |-- hooks/                 # Notification hook
|   +-- skills/                # Claude-parity workflow skills
|-- config/
|   |-- starship.toml          # Starship prompt configuration
|   +-- ripgrep/config         # Ripgrep defaults
|-- tests/                     # Test suite (7 test files)
+-- .devcontainer/             # Example devcontainer configurations
```

---

## Customization

### Local Override Files

Create these files for machine-specific configuration (all gitignored):

| File | Purpose |
|------|---------|
| `~/.bashrc.local` | Bash-specific overrides |
| `~/.zshrc.local` | Zsh-specific overrides |
| `~/.exports.local` | Environment variables (PATH additions, API keys) |
| `~/.aliases.local` | Extra aliases |
| `~/.functions.local` | Extra functions |

### Opinionated Aliases

By default, `grep` and `find` are not shadowed. To enable rg/fd replacements:

```bash
# Add to ~/.exports.local
export DOTFILES_OPINIONATED_ALIASES=1
```

### Installation Toggles

Control what gets installed by setting environment variables before running `install.sh`. Set these in `~/.exports.local` or in your devcontainer's `remoteEnv`:

| Variable | Default | Effect |
|----------|---------|--------|
| `DOTFILES_NO_AI_TOOLS=1` | off | Skip Claude Code, Codex CLI, ast-grep, difftastic, and all AI config (~/.claude, ~/.codex) |
| `DOTFILES_NO_ATUIN=1` | off | Skip atuin shell history and bash-preexec |
| `DOTFILES_NO_GIT_HOOKS=1` | off | Skip global git hooks (conventional commits, gitleaks pre-commit) |
| `DOTFILES_NO_STATE_PERSISTENCE=1` | off | Skip state persistence (no volume or Codespaces tier) |
| `DOTFILES_NO_SSH_SIGNING=1` | off | Skip SSH commit signing auto-detection (skips ssh-add and ~/.ssh access) |
| `DOTFILES_OPINIONATED_ALIASES=1` | off | Shadow `grep` with rg and `find` with fd |

AI tools (Claude Code + Codex CLI) are installed as native binaries in devcontainer environments only. On host machines, users manage their own AI tool installations.

### Diagnostics

Run `dotfiles-doctor` to verify installation health:

```
$ dotfiles-doctor
dotfiles doctor -- checking installation health

== Symlinks ==
  ok  .bashrc -> /home/user/.dotfiles/shell/.bashrc
  ok  .zshrc -> /home/user/.dotfiles/shell/.zshrc
  ok  git config includes dotfiles settings
  ...

== Core Tools ==
  ok  git (git version 2.43.0)
  ok  ripgrep (ripgrep 14.1.1)
  ...

== Git Configuration ==
  ok  git user.name: Your Name
  ok  commit signing configured
  ...

== Summary ==
  27 passed, 0 warnings, 0 failed
```

### Shell Profiling

Profile zsh startup to find bottlenecks:

```bash
ZSH_PROFILE=1 zsh -i -c exit
```

This uses `zprof` to show where time is spent during initialization.

---

## Security Model

Security is defense-in-depth across multiple layers:

### Secret Scanning (Gitleaks)

A global `pre-commit` hook scans every commit for secrets (API keys, passwords, tokens) using gitleaks. Applied to all repos via `core.hooksPath`. Silently passes if gitleaks is not installed. Per-repo hooks supported via `.git/hooks/pre-commit.local`.

### Claude Code Permission Hooks

| Hook | Trigger | Action |
|------|---------|--------|
| `pre-security.sh` | Read/Write/Edit/Bash | Blocks access to ~50 sensitive file patterns and credential directories |
| `pre-commit-validate.sh` | `git commit` | Enforces conventional commits, blocks AI attribution |
| `pre-code-no-emoji.sh` | Write/Edit | Blocks decorative emoji in code files |

### Credential Protection

The following are blocked across Claude Code settings, hooks, and CLAUDE.md:

- **Secret files**: `.env*`, `credentials*`, `*secret*`, `*.pem`, `*.key`, `*.tfvars`, `*.ppk`, `*.jks`, `*.keystore`, `*.pfx`, `*.p12`
- **Credential directories**: `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.azure`, `~/.config/gcloud`, `~/.docker`, `~/.kube`, and 10+ more
- **Credential files**: `~/.npmrc`, `~/.pypirc`, `~/.netrc`, `~/.git-credentials`, `~/.pgpass`, `~/.my.cnf`, `~/.mongorc.js`
- **Path traversal**: `../` patterns blocked unless explicitly approved

### SSH Commit Signing

Git is configured to use SSH keys (not GPG) for commit signing. The installer auto-detects keys from the SSH agent (prefers ed25519) or local `~/.ssh/*.pub` files. Works transparently in devcontainers via VS Code's SSH agent forwarding.

### Git Hook Enforcement

Applied globally via `core.hooksPath = ~/.config/git/hooks`:

- **Conventional commits** enforced (type, scope, description format)
- **AI attribution** blocked (Claude, GPT, Copilot mentions)
- **Co-Authored-By** lines blocked
- **Emoji characters** blocked in commit messages
- Per-repo hooks supported via `.local` suffix (e.g., `commit-msg.local`)
- Bypass: `git commit --no-verify` (not recommended)

---

## Testing

```bash
# Lint all shell scripts
make lint

# Run full test suite (unit + packages + integration)
make test

# Run individual suites
make test-unit
make test-packages
make test-integration

# Additional test scripts
bash tests/test-security-hook.sh   # Security hook tests (89 cases)
bash tests/test-functions.sh       # Shell function tests
```

| Test File | Coverage |
|-----------|----------|
| `test-install.sh` | Symlinks, tools, environment, git config, shell startup |
| `test-security-hook.sh` | Commit-msg hook (conventional commits, AI attribution, emoji) |
| `unit-tests.sh` | Bootstrap functions (symlinks, backups, merge) |
| `test-functions.sh` | Shell functions (extract, killport, git helpers) |
| `test-packages.sh` | Package installation and tool config |
| `validate-dotfiles.sh` | Post-install health checks |

---

## Troubleshooting

### Dotfiles Not Installing in VS Code

1. Check VS Code settings for dotfiles repository URL
2. Verify `install.sh` has execute permissions
3. Check devcontainer logs: View > Output > Log (Remote)

### Command Not Found

```bash
source ~/.bashrc  # or ~/.zshrc
```

### Completions Not Working

**Bash**: `type _completion_loader` to check if bash-completion is loaded, then `source ~/.bashrc`.

**Zsh**: Remove stale cache and restart:
```bash
rm ~/.cache/zsh/zcompdump* && exec zsh
```

### Symlink Issues

The installer backs up existing files to `~/.dotfiles_backup_<timestamp>`:

```bash
# Restore originals
cp -r ~/.dotfiles_backup_<timestamp>/* ~/
```

### Commit Signing Errors

If commits fail with signing errors, check your setup:

```bash
dotfiles-doctor  # Shows signing key status
ssh-add -L       # List keys in agent
git config user.signingkey  # Show configured key
```

To disable signing: `git config --global commit.gpgsign false`

### Everything Else

Run `dotfiles-doctor` for a comprehensive health check of symlinks, tools, and configuration.

---

## Environment Variables

Key variables set by these dotfiles (see `shell/exports.sh` for the complete list):

| Variable | Value |
|----------|-------|
| `EDITOR` | nvim / vim / vi (first available) |
| `HISTSIZE` | 100000 |
| `FZF_DEFAULT_COMMAND` | fd (hidden files, exclude .git) |
| `FZF_DEFAULT_OPTS` | TokyoNight color theme, reverse layout |
| `BAT_THEME` | OneHalfDark |
| `DOCKER_BUILDKIT` | 1 |
| `CLAUDE_CONFIG_DIR` | ~/.claude |
| `XDG_CONFIG_HOME` | ~/.config |

---

## Resources

- [Dotfiles Guide](https://dotfiles.github.io/)
- [Starship Documentation](https://starship.rs/)
- [FZF GitHub](https://github.com/junegunn/fzf)
- [Zoxide GitHub](https://github.com/ajeetdsouza/zoxide)
- [AGENTS.md Standard](https://agents.md/)
- [Claude Code Hooks Guide](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [VS Code Dotfiles Guide](https://code.visualstudio.com/docs/remote/containers#_personalizing-with-dotfile-repositories)
- [SSH Commit Signing](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#ssh-commit-signature-verification)

## License

MIT License - Feel free to use and modify!
