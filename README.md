# Dotfiles

Modern command-line productivity toolkit with automatic VS Code integration for devcontainers and Codespaces.

## Quick Start

### For VS Code Devcontainers/Codespaces

1. **Fork this repository** on GitHub

2. **Configure VS Code**:
   - Open Settings (Cmd/Ctrl + ,)
   - Search for "dotfiles"
   - Set "Dotfiles: Repository" to `iggycoloma/dotfiles`
   - Set "Dotfiles: Install Command" to `install.sh`

3. **Done!** Your dotfiles will automatically install in every new devcontainer/Codespace

### Manual Installation

```bash
git clone https://github.com/iggycoloma/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./install.sh
```

## What's Included

### Essential Tools

- **fzf**: Fuzzy finder for files, history, and more
- **zoxide**: Smart directory jumping (replacement for cd)
- **ripgrep (rg)**: Fast grep alternative
- **fd**: Fast find alternative
- **bat**: Cat with syntax highlighting
- **git-delta**: Beautiful git diffs
- **starship**: Cross-shell prompt
- **jq**: JSON processor
- **eza**: Modern ls replacement (local machines)
- **lazygit**: Terminal UI for git (local machines)
- **atuin**: Shell history with SQLite and context-aware search

## Codex CLI Parity

These dotfiles now include a Codex configuration bundle under `codex/` to mirror key Claude Code workflows and guardrails.

- `~/.codex/AGENTS.md` for global operating rules (security, commit standards, review posture)
- `~/.codex/skills/claude-parity` for command-style workflow playbooks (context-prime, commit, PR, debug, test, pipeline)
- Safe installer behavior: runtime files like `auth.json`, `history.jsonl`, `sessions/`, and `tmp/` are preserved locally
- Shell shortcuts:
  - `cx` -> `codex`
  - `cxe` -> `codex exec`
  - `cxr` -> `codex review --uncommitted`

## Global Git Hooks

These dotfiles enable a single global hooks directory so commit message checks apply to every repository automatically.

- Location: `~/.config/git/hooks` (configured via `core.hooksPath` in `git/.gitconfig`)
- Installed by: `bootstrap/symlinks.sh` (makes hooks executable and symlinks the directory)
- Commit template: `~/.gitmessage` (configured via `commit.template`)

Enforced by `commit-msg` (global):
- Conventional Commits subject format (`<type>(scope): description`)
- Allowed types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Minimum subject length (>= 10)
- No AI tool attribution (e.g., Claude, GPT, Copilot, "AI-generated")
- No co-authoring lines (`Co-Authored-By:`/`Co-authored by:`)
- No emojis in commit messages
- Merge commits are allowed as-is

Scope and customization:
- Applies to all repositories once dotfiles are installed; no per-repo setup required
- Repo-level hooks are supported: if a repository has `.git/hooks/commit-msg.local` (or `.git/hooks/commit-msg`), it runs first, then the global checks
- To adjust global rules, edit `git/hooks/commit-msg` in this repo and re-run the installer

## Git Configuration

### How It Works

These dotfiles provide **standardized git settings** (aliases, delta configuration, colors, etc.) while keeping your **personal identity** (user.name and user.email) separate.

**The Setup:**

1. **Your `~/.gitconfig`** contains your personal identity:
   ```ini
   [user]
       name = Your Name
       email = your@email.com
   ```

2. **Dotfiles provide standardized settings** via include:
   ```ini
   [include]
       path = /home/user/.dotfiles/git/.gitconfig
   ```

3. **Git merges both configurations** automatically

### For VS Code Devcontainers

- VS Code automatically copies your local `~/.gitconfig` (with your identity) into the container
- The dotfiles installer adds an include directive pointing to `~/.dotfiles/git/.gitconfig`
- Result: Your personal identity + standardized settings work together

### For GitHub Codespaces

- Codespaces automatically configures git identity from your GitHub profile
- The dotfiles installer adds an include directive for standardized settings

### For Local Machines

If you don't already have git configured:

```bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

The install script will add the dotfiles include directive automatically.

## Repository Structure

```
dotfiles/
├── install.sh              # Main installation script
├── shell/
│   ├── .bashrc            # Bash configuration
│   ├── .zshrc             # Zsh configuration
│   ├── aliases.sh         # Command aliases
│   ├── functions.sh       # Useful shell functions
│   └── exports.sh         # Environment variables
├── git/
│   ├── .gitconfig         # Git configuration
│   └── .gitignore_global  # Global gitignore patterns
├── claude-code/            # Claude Code configuration
│   ├── agents/            # Specialized agents
│   ├── commands/          # Slash commands
│   ├── hooks/             # Pre/post hooks
│   └── settings.json      # Claude Code settings
├── codex/                 # Codex CLI configuration
│   ├── AGENTS.md          # Global Codex instructions
│   └── skills/            # Custom Codex skills
├── starship.toml          # Starship prompt configuration
└── tmux/
    └── .tmux.conf         # Tmux configuration (local only)
```

## Customization

### Local Overrides

Create local configuration files that won't be tracked in git:

```bash
~/.bashrc.local      # Local bash configuration
~/.zshrc.local       # Local zsh configuration
~/.exports.local     # Local environment variables (including git identity)
~/.aliases.local     # Local aliases
~/.functions.local   # Local functions
```

### Opinionated Aliases (opt-in)

By default, core utilities like `grep` and `find` are not shadowed to avoid breaking scripts. To enable opinionated aliasing (`grep` -> `rg`, `find` -> `fd`), set:

```bash
export DOTFILES_OPINIONATED_ALIASES=1
```

Add this to `~/.exports.local` or your shell profile and reload your shell.

## Troubleshooting

### Dotfiles not installing in VS Code

1. Check VS Code settings for dotfiles repository URL
2. Verify `install.sh` has execute permissions
3. Check devcontainer logs: View -> Output -> Log (Remote)

### Command not found after installation

```bash
source ~/.bashrc  # or ~/.zshrc
```

### Completions not working

**Bash**: `type _completion_loader` to check if bash-completion is loaded, then `source ~/.bashrc`

**Zsh**: `rm ~/.zcompdump* && exec zsh` to rebuild completion cache

### Symlink issues

The installer backs up existing files to `~/.dotfiles_backup_<timestamp>`.

To restore originals:

```bash
cp -r ~/.dotfiles_backup_<timestamp>/* ~/
```

## Devcontainer Support

These dotfiles automatically adapt to your environment:

**On Host Machines**: Configuration files are symlinked to this repository for easy updates.

**In Devcontainers/Codespaces**: Files are copied with intelligent merging to work with Docker named volumes.

### Quick Start

1. Copy the example configuration:
   ```bash
   mkdir -p .devcontainer
   cp ~/.dotfiles/.devcontainer/example/devcontainer.json .devcontainer/
   ```

2. Update the repository reference in `.devcontainer/devcontainer.json`

3. Reopen in container: `Cmd/Ctrl+Shift+P` -> "Dev Containers: Reopen in Container"

See [.devcontainer/example/README.md](.devcontainer/example/README.md) for detailed documentation.

## Environment Variables

Key environment variables set by these dotfiles:

```bash
EDITOR=nvim              # Or vim/vi (first available)
HISTSIZE=100000         # Large command history
FZF_DEFAULT_COMMAND     # Use fd/rg for fzf
BAT_THEME=OneHalfDark   # Dark theme for bat
```

See `shell/exports.sh` for the complete list.

## Resources

- [Dotfiles Guide](https://dotfiles.github.io/)
- [Starship Documentation](https://starship.rs/)
- [FZF GitHub](https://github.com/junegunn/fzf)
- [Zoxide GitHub](https://github.com/ajeetdsouza/zoxide)
- [VS Code Dotfiles Guide](https://code.visualstudio.com/docs/remote/containers#_personalizing-with-dotfile-repositories)

## License

MIT License - Feel free to use and modify!
