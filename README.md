# Dotfiles

Modern CLI productivity toolkit with agentic coding tool configuration, automatic devcontainer/Codespaces integration, and defense-in-depth security.

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

---

## What's Included

### CLI Tools

All tools are installed automatically. On Linux, most come from GitHub releases with checksum verification (musl-static builds for portability). On macOS, Homebrew handles everything.

| Tool | Purpose | Category |
|------|---------|----------|
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder for files, history, and more | Core |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (rg) | Fast regex search across files | Core |
| [fd](https://github.com/sharkdp/fd) | Fast file finder | Core |
| [bat](https://github.com/sharkdp/bat) | Cat with syntax highlighting | Core |
| [jq](https://github.com/jqlang/jq) | JSON processor | Core |
| [starship](https://starship.rs/) | Cross-shell prompt with git status | Enhanced |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smart directory jumping (replaces cd) | Enhanced |
| [eza](https://github.com/eza-community/eza) | Modern ls replacement with git integration | Enhanced |
| [git-delta](https://github.com/dandavison/delta) | Beautiful, syntax-highlighted git diffs | Enhanced |
| [atuin](https://github.com/atuinsh/atuin) | Shell history with SQLite and context search | Enhanced |
| [sd](https://github.com/chmln/sd) | Find-and-replace (modern sed, PCRE regex) | Enhanced |
| [ast-grep](https://ast-grep.github.io/) (sg) | Structural code search by AST | Enhanced |
| [difftastic](https://github.com/Wilfred/difftastic) (difft) | AST-aware file diff (ignores formatting) | Enhanced |
| [scc](https://github.com/boyter/scc) | Fast code statistics (LOC, complexity) | Enhanced |
| [yq](https://github.com/mikefarah/yq) | YAML/TOML/XML editor (preserves comments) | Enhanced |
| [watchexec](https://github.com/watchexec/watchexec) | File watcher for auto-test/rebuild | Enhanced |
| [gitleaks](https://github.com/gitleaks/gitleaks) | Secret scanner (pre-commit hook) | Security |
| [shellcheck](https://github.com/koalaman/shellcheck) | Shell script linter | Quality |
| [lazygit](https://github.com/jesseduffield/lazygit) | Terminal UI for git (host only) | Optional |
| [bottom](https://github.com/ClementTsang/bottom) (btm) | System monitor (host only) | Optional |

### Shell Configuration

**Aliases** (`shell/aliases.sh`): 80+ aliases for git, docker, kubernetes, python, navigation, and modern tool replacements. Core utilities like `grep` and `find` are not shadowed by default -- set `DOTFILES_OPINIONATED_ALIASES=1` to enable.

**Functions** (`shell/functions.sh`): 25+ utility functions including `mkcd`, `extract`, `killport`, `gcof` (fzf branch picker), `glf` (fzf git log), `dotfiles-doctor` (installation diagnostic), `serve` (quick HTTP server), docker helpers, and smart `cat` (uses bat in terminal, plain cat in pipes).

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

Git settings live in `git/.gitconfig` and are included via `[include]` into your personal `~/.gitconfig`. Your identity (name/email) stays separate and is never overwritten.

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

This repo configures two AI coding assistants with shared guardrails and workflows.

**Architecture:**

| File | Deployed to | Read by | Purpose |
|------|-------------|---------|---------|
| `AGENTS.md` (root) | Stays in repo | Copilot, Cursor, Windsurf, Amp, Devin | Per-repo shared instructions |
| `claude-code/CLAUDE.md` | `~/.claude/CLAUDE.md` | Claude Code | Global Claude Code instructions |
| `codex/AGENTS.md` | `~/.codex/AGENTS.md` | Codex CLI | Global Codex instructions |

Each tool-specific file is **self-contained** (full guardrails + CLI preferences) because these tools don't follow cross-file references. The root `AGENTS.md` serves tools that discover it by convention when working inside this repo.

**Shared guardrails** (enforced in all three files):
- No emoji in code, docs, or commits
- Conventional commits; no AI attribution or Co-Authored-By
- Never access credential files or directories (~50 blocked patterns)
- Prefer modern CLI tools (rg, fd, sg, difft, sd, bat, scc, yq)
- Run shellcheck on shell scripts before committing

**Claude Code** (`claude-code/`):

| Component | Count | Purpose |
|-----------|-------|---------|
| Hooks | 5 | Security (credential blocking), conventional commits, no-emoji, auto-shellcheck (PostToolUse), idle notification |
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

These dotfiles automatically adapt to devcontainers and Codespaces.

### How It Works

A single named volume persists CLI tool state across container rebuilds. The installer creates directory symlinks into the volume and force-copies fresh configs from dotfiles on every boot.

**What persists** (volume): credentials, auth tokens, shell history, sessions, plans, caches.

**What refreshes** (copied from dotfiles): settings.json, CLAUDE.md, AGENTS.md, hooks, agents, commands, skills.

### Per-Project Setup

Add one volume mount to your project's `.devcontainer/devcontainer.json`:

```json
{
  "mounts": [
    "source=${devcontainerId}-state,target=/home/vscode/.devcontainer-state,type=volume"
  ]
}
```

The dotfiles installer handles everything else: ownership fixes, directory wiring, environment variables, and config deployment. See `.devcontainer/example/` for a complete example.

### Git in Devcontainers

- **VS Code** copies your local `~/.gitconfig` (with identity) into the container automatically
- **Codespaces** configures git identity from your GitHub profile
- The installer adds an `[include]` directive for dotfiles settings (delta, aliases, hooks, etc.)
- SSH agent is forwarded by VS Code -- commit signing works without distributing keys

---

## Repository Structure

```
dotfiles/
|-- install.sh                 # Main installer (detects env, orchestrates everything)
|-- AGENTS.md                  # Shared AI tool instructions (per-repo)
|-- bootstrap/
|   |-- detect.sh              # Environment/OS/package manager detection
|   |-- logging.sh             # Colored log functions
|   |-- packages.sh            # Tool installation (apt/apk/brew + GitHub releases)
|   |-- symlinks.sh            # Symlink creation with backup and devcontainer support
|   |-- completions.sh         # Shell completion setup (bash + zsh + zinit)
|   +-- merge-configs.sh       # Config merge utilities
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
|   |-- hooks/                 # 5 hooks (security, commits, emoji, shellcheck, notify)
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

### Diagnostics

Run `dotfiles-doctor` to verify installation health:

```
$ dotfiles-doctor
dotfiles doctor -- checking installation health

== Symlinks ==
  ok  .bashrc -> /home/user/.dotfiles/shell/.bashrc
  ok  .zshrc -> /home/user/.dotfiles/shell/.zshrc
  ok  git config (XDG) -> /home/user/.dotfiles/git/.gitconfig
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
| `post-shellcheck.sh` | Write/Edit | Auto-runs shellcheck on .sh files (informational) |

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
# Run all validation tests
bash tests/test-install.sh

# Run security hook tests (89 test cases)
bash tests/test-security-hook.sh

# Run unit tests
bash tests/unit-tests.sh

# Run function tests
bash tests/test-functions.sh
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
