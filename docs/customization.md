# Customization

How to extend or override the dotfiles defaults. For the full tool inventory,
see [`tooling.md`](tooling.md). For per-tool agentic behavior, see
[`agentic-tooling.md`](agentic-tooling.md).

## Local override files

Create any of these for machine-specific configuration. All are gitignored:

| File                   | Purpose                                          |
|------------------------|--------------------------------------------------|
| `~/.bashrc.local`      | Bash-specific overrides                          |
| `~/.zshrc.local`       | Zsh-specific overrides                           |
| `~/.exports.local`     | Environment variables (PATH additions, API keys) |
| `~/.aliases.local`     | Extra aliases                                    |
| `~/.functions.local`   | Extra functions                                  |

The shell startup files source these after the dotfiles' own configs, so
overrides win.

## Installation toggles

Set these before running `install.sh`, or put them in `~/.exports.local`, or
in your devcontainer's `remoteEnv`:

| Variable                              | Default | Effect                                                                  |
|---------------------------------------|---------|-------------------------------------------------------------------------|
| `DOTFILES_NO_AI_TOOLS=1`              | off     | Skip Claude Code, Codex CLI, ast-grep, difftastic, and all AI configs   |
| `DOTFILES_NO_ATUIN=1`                 | off     | Skip atuin shell history and bash-preexec                               |
| `DOTFILES_NO_GIT_HOOKS=1`             | off     | Skip global git hooks (conventional commits, gitleaks pre-commit)       |
| `DOTFILES_NO_STATE_PERSISTENCE=1`     | off     | Skip state persistence (no volume or Codespaces tier wiring)            |
| `DOTFILES_NO_SSH_SIGNING=1`           | off     | Skip SSH commit signing auto-detection                                  |
| `DOTFILES_OPINIONATED_ALIASES=1`      | off     | Shadow `grep` with `rg` and `find` with `fd`                            |
| `DOTFILES_INSTALL_AGENTIC=1`          | off     | Deploy the opt-in agentic harness to `~/.agentic/`                      |
| `DOTFILES_DEVCONTAINER_EGRESS=1`      | off     | Install iptables egress allowlist in devcontainers (needs `NET_ADMIN`)  |
| `DOTFILES_EGRESS_EXTRA_HOSTS=a,b,c`   | (empty) | Comma-separated hosts to add to the egress allowlist                    |
| `DOTFILES_NO_SSH_SIGNING=1`           | off     | (same as above)                                                         |

AI tools (Claude Code + Codex CLI) install as native binaries in devcontainer
environments only. On hosts, users manage their own AI installs.

## Opinionated aliases

By default, `grep` and `find` are not shadowed -- some scripts and tools
depend on their exact behavior. Set `DOTFILES_OPINIONATED_ALIASES=1` in
`~/.exports.local` to enable the modern replacements:

```bash
export DOTFILES_OPINIONATED_ALIASES=1
```

After this, `grep` invokes `rg` and `find` invokes `fd` with appropriate
flag translation.

## Per-project AI tool overrides

Drop a `.claude/settings.local.json` in any project to merge per-project
permissions, allowed domains, and MCP servers on top of the global defaults.
This file is gitignored by default in Claude Code; the dotfiles' global
deny-list also blocks it from Read/Write/Edit, so the file's contents never
leak into a session even by accident.

Same pattern for Codex: `.codex/config.local.toml` (when supported).

Effective settings precedence (Claude Code): managed > CLI > local > project
> user. A project-local entry strictly adds to (doesn't replace) the global
allowlist.

Common uses:

```jsonc
// .claude/settings.local.json
{
  "permissions": {
    "allow": [
      "Bash(docker compose:*)",
      "Bash(terraform plan:*)"
    ]
  },
  "sandbox": {
    "network": {
      "allowedDomains": [
        "registry-1.docker.io",
        "docker.io",
        "my-internal-package-repo.example.com"
      ]
    }
  }
}
```

## Per-devcontainer extensions

For project-specific dotfiles behavior, set environment variables in the
project's `devcontainer.json`:

```jsonc
{
  "remoteEnv": {
    "DOTFILES_DEVCONTAINER_EGRESS": "1",
    "DOTFILES_EGRESS_EXTRA_HOSTS": "docker.io,registry-1.docker.io,my-internal.example.com",
    "DOTFILES_NO_AI_TOOLS": "0"
  },
  "runArgs": [
    "--cap-add=NET_ADMIN"
  ]
}
```

In Codespaces, set the same toggles as [account-specific
secrets](https://docs.github.com/en/codespaces/managing-your-codespaces/managing-your-account-specific-secrets-for-github-codespaces);
Codespaces makes secrets available as environment variables inside the
container automatically.

## Diagnostics

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

## Shell profiling

Profile zsh startup to find bottlenecks:

```bash
ZSH_PROFILE=1 zsh -i -c exit
```

This uses `zprof` to show where time is spent during initialization.

## Environment variables (key ones)

The complete list lives in `shell/exports.sh`. Highlights:

| Variable                     | Value                                              |
|------------------------------|----------------------------------------------------|
| `EDITOR`                     | `nvim` / `vim` / `vi` (first available)            |
| `HISTSIZE`                   | 100000                                             |
| `FZF_DEFAULT_COMMAND`        | `fd` (hidden files, exclude `.git`)                |
| `FZF_DEFAULT_OPTS`           | TokyoNight color theme, reverse layout             |
| `BAT_THEME`                  | OneHalfDark                                        |
| `DOCKER_BUILDKIT`            | 1                                                  |
| `CLAUDE_CONFIG_DIR`          | `~/.claude`                                        |
| `XDG_CONFIG_HOME`            | `~/.config`                                        |

## Troubleshooting

### Dotfiles not installing in VS Code

1. Check VS Code settings for the dotfiles repository URL.
2. Verify `install.sh` has execute permissions.
3. Check devcontainer logs: View -> Output -> Log (Remote).

### Command not found

```bash
source ~/.bashrc   # or ~/.zshrc
```

### Completions not working

**Bash**: `type _completion_loader` to check if bash-completion is loaded,
then `source ~/.bashrc`.

**Zsh**: remove stale cache and restart:

```bash
rm ~/.cache/zsh/zcompdump* && exec zsh
```

### Symlink issues

The installer backs up existing files to `~/.dotfiles_backup_<timestamp>`:

```bash
cp -r ~/.dotfiles_backup_<timestamp>/* ~/
```

### Commit signing errors

```bash
dotfiles-doctor                 # Shows signing key status
ssh-add -L                      # List keys in agent
git config user.signingkey      # Show configured key
```

To disable signing: `git config --global commit.gpgsign false`.

If signing breaks inside the Claude Code sandbox on Linux/WSL2 hosts, see
the agent-vs-file signing note in
[sandbox.md](sandbox.md#ssh-agent-and-signed-commits).
