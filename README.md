# Dotfiles

Modern command-line productivity toolkit with automatic VS Code integration for devcontainers and Codespaces.

## Quick Start

### For VS Code Devcontainers/Codespaces

1. **Fork this repository** on GitHub

2. **Configure VS Code**:
   - Open Settings (Cmd/Ctrl + ,)
   - Search for "dotfiles"
   - Set "Dotfiles: Repository" to `yourusername/dotfiles`
   - Set "Dotfiles: Install Command" to `install.sh`

3. **Done!** Your dotfiles will automatically install in every new devcontainer/Codespace

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles

# Run installation
cd ~/.dotfiles
chmod +x install.sh
./install.sh

# Configure git with your details
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

Installation takes 2-3 minutes in containers, 5-15 minutes on local machines.

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

### Shell Completions

Intelligent autocomplete for both Bash and Zsh:

**Bash**:
- bash-completion v2 with colored output
- Case-insensitive matching
- Immediate option display

**Zsh**:
- Visual menu selection with arrow keys
- Fish-style autosuggestions from history
- Real-time syntax highlighting
- Fuzzy matching with typo correction

**Auto-generated completions for**: git, docker, kubectl, gh, terraform, aws, poetry, cargo, and more

### Git Aliases

```bash
gs      # git status
gl      # git log (pretty, graph)
gco     # git checkout
gcb     # git checkout -b
ga      # git add
gc      # git commit -v
gp      # git push
gpl     # git pull
gd      # git diff
gst     # git stash
lg      # lazygit (if installed)
```

See `shell/aliases.sh` for the complete list.

## Global Git Hooks

These dotfiles enable a single global hooks directory so commit message checks apply to every repository automatically.

- Location: `~/.config/git/hooks` (configured via `core.hooksPath` in `git/.gitconfig: [core] hooksPath = ~/.config/git/hooks`)
- Installed by: `bootstrap/symlinks.sh` (makes hooks executable and symlinks the directory)
- Commit template: `~/.gitmessage` (configured via `commit.template`)

Enforced by `commit-msg` (global):
- Conventional Commits subject format (`<type>(scope): description`)
- Allowed types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Minimum subject length (≥ 10)
- No AI tool attribution (e.g., Claude, GPT, Copilot, “AI-generated”)
- No co-authoring lines (`Co-Authored-By:`/`Co-authored by:`)
- No emojis in commit messages
- Merge commits are allowed as-is

Scope and customization:
- Applies to all repositories once dotfiles are installed; no per-repo setup required
- Repo-level hooks are supported: if a repository has `.git/hooks/commit-msg.local` (or `.git/hooks/commit-msg`), it runs first, then the global checks
- To adjust global rules, edit `git/hooks/commit-msg` in this repo and re-run the installer

### Shell Functions

```bash
mkcd <dir>              # Create directory and cd into it
extract <file>          # Extract any archive format
killport <port>         # Kill process on specific port
gbdm                    # Delete merged git branches
gcof                    # Checkout git branch with fzf
weather [location]      # Get weather report
serve [port]            # Serve current directory over HTTP
backup <file>           # Create timestamped backup
```

### FZF Integration

Keyboard shortcuts for fuzzy finding:

- **Ctrl+R**: Search command history
- **Ctrl+T**: Search files in current directory
- **Alt+C**: Search and cd into directories

### Directory Navigation

```bash
..              # cd ..
...             # cd ../..
z <partial>     # Jump to frecent directory with zoxide
zi              # Interactive directory selection
```

## Repository Structure

```
dotfiles/
├── install.sh              # Main installation script
├── README.md              # This file
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
~/.exports.local     # Local environment variables
~/.gitconfig.local   # Local git configuration
~/.aliases.local     # Local aliases
~/.functions.local   # Local functions
```

### Example: Add Custom Alias

```bash
# Add to ~/.aliases.local
echo "alias myproject='cd ~/code/my-project'" >> ~/.aliases.local

# Reload shell
source ~/.bashrc
```

### Adding Your Own Tools

Edit `install.sh` to add your preferred tools. The script automatically detects:
- Operating system (macOS, Ubuntu, Debian, etc.)
- Environment type (local, devcontainer, codespaces)
- Available package managers (brew, apt, etc.)

### Opinionated Aliases (opt-in)

By default, core utilities like `grep` and `find` are not shadowed to avoid breaking scripts. To enable opinionated aliasing (`grep` -> `rg`, `find` -> `fd`), set:

```bash
export DOTFILES_OPINIONATED_ALIASES=1
```

Add this to `~/.exports.local` or your shell profile and reload your shell.

## Shell Completions

### Testing Completions

**Bash**:
```bash
git che<Tab>              # Completes to "checkout"
git checkout <Tab>        # Lists all branches
docker <Tab>              # Shows all docker commands
```

**Zsh**:
```bash
git checkout <Tab>        # Arrow keys to navigate menu
cd /u/l/b<Tab>           # Expands to /usr/local/bin
git st                    # Shows "git status" in gray (from history)
                          # Press → to accept
```

### Troubleshooting Completions

**Bash**:
```bash
# Check if bash-completion is loaded
type _completion_loader

# Reload if needed
source ~/.bashrc
```

**Zsh**:
```bash
# Rebuild completion cache
rm ~/.zcompdump*
exec zsh

# Verify autosuggestions
echo $ZSH_AUTOSUGGEST_VERSION
```

## Tmux Usage (Local Machines Only)

```bash
# Start new session
tmux

# Key bindings
Ctrl+a, d         # Detach
Ctrl+a, |         # Split horizontal
Ctrl+a, -         # Split vertical
Alt+Arrow keys    # Navigate panes
Ctrl+a, H/J/K/L   # Resize panes
```

## Starship Prompt

The prompt displays:
- Username and hostname
- Current directory (truncated)
- Git branch and status
- Language versions (Python, Node, Rust, Go)
- Command duration (if > 2s)
- Error status

Customize in `starship.toml`.

## Troubleshooting

### Dotfiles not installing in VS Code

1. Check VS Code settings for dotfiles repository URL
2. Verify `install.sh` has execute permissions
3. Check devcontainer logs: View → Output → Log (Remote)

### Command not found after installation

```bash
# Reload your shell
source ~/.bashrc  # or ~/.zshrc

# Or restart your terminal
```

### Completions not working

See Shell Completions section above for detailed troubleshooting steps.

### Fixing permissions

```bash
chmod +x ~/.dotfiles/install.sh
```

### Symlink issues

The installer backs up existing files to `~/.dotfiles_backup_<timestamp>`.

To restore originals:

```bash
cp -r ~/.dotfiles_backup_<timestamp>/* ~/
```

## Updating

```bash
cd ~/.dotfiles
git pull
./install.sh
```

The installation script is idempotent and safe to run multiple times.

## Claude Code Integration

Comprehensive Claude Code setup included:

- **Agents**: Specialized sub-agents for code review, debugging, testing, refactoring, security audits
- **Commands**: Slash commands for common workflows (`/commit`, `/test`, `/debug`, `/refactor`, `/pr-create`)
- **Hooks**: Validation hooks for commit messages, code formatting, security checks

See `claude-code/*/README.md` files for detailed documentation.

## Devcontainer Support

These dotfiles automatically adapt to your environment:

**On Host Machines**: Configuration files are symlinked to this repository for easy updates.

**In Devcontainers/Codespaces**: Files are copied with intelligent merging to work with Docker named volumes. Shared resources (agents, commands, hooks) stay up-to-date while project-specific settings are preserved.

### Quick Start

1. **Copy the example configuration**:
   ```bash
   mkdir -p .devcontainer
   cp ~/.dotfiles/.devcontainer/example/devcontainer.json .devcontainer/
   ```

2. **Update the repository reference**:
   Edit `.devcontainer/devcontainer.json` and change `"repository": "yourusername/.dotfiles"`

3. **Reopen in container**:
   Press `Cmd/Ctrl+Shift+P` → "Dev Containers: Reopen in Container"

**For detailed documentation**, including volume configuration, merge strategy, troubleshooting, and project-specific overrides, see [.devcontainer/example/README.md](.devcontainer/example/README.md).

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

## Credits

Inspired by various dotfiles repositories and the amazing CLI tool community.
