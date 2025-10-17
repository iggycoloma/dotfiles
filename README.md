# Dotfiles

Modern command-line productivity toolkit with automatic VS Code integration for devcontainers and Codespaces.

## Features

- 🚀 **Modern CLI Tools**: fzf, zoxide, ripgrep, fd, bat, eza, delta, and more
- ⚡ **Fast Prompt**: Starship prompt with git integration
- 🎨 **Productive Aliases**: Extensive git aliases and command shortcuts
- 📦 **VS Code Compatible**: Automatic installation in devcontainers and Codespaces
- 🔧 **Environment Detection**: Smart installation based on local vs container environment
- 🐚 **Shell Agnostic**: Works with bash and zsh
- ✨ **Best-in-class Completions**: Comprehensive autocomplete for git, docker, kubectl, and more
  - Zsh: autosuggestions, syntax highlighting, fuzzy matching
  - Bash: bash-completion v2 with colored output
  - Auto-generated completions for 20+ tools

## Quick Start

### For VS Code Devcontainers/Codespaces

1. **Fork this repository** on GitHub

2. **Configure VS Code to use your dotfiles**:
   - Open VS Code Settings (Cmd/Ctrl + ,)
   - Search for "dotfiles"
   - Set "Dotfiles: Repository" to your forked repo URL (e.g., `yourusername/dotfiles`)
   - Set "Dotfiles: Install Command" to `install.sh` (default)

3. **Create or open a devcontainer** - your dotfiles will be automatically installed!

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles

# Run the installation script
cd ~/.dotfiles
chmod +x install.sh
./install.sh
```

### First-Time Setup

After installation, customize your git configuration:

```bash
# Edit your name and email
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## Repository Structure

```
dotfiles/
├── install.sh              # Main installation script (VS Code compatible)
├── README.md              # This file
├── COMPLETIONS.md         # Detailed completion guide
│
├── shell/
│   ├── .bashrc            # Bash configuration
│   ├── .zshrc             # Zsh configuration
│   ├── aliases.sh         # Command aliases
│   ├── functions.sh       # Useful shell functions
│   └── exports.sh         # Environment variables
│
├── git/
│   ├── .gitconfig         # Git configuration
│   └── .gitignore_global  # Global gitignore patterns
│
├── claude-code/            # Claude Code configuration
│   ├── agents/            # Specialized agents
│   ├── commands/          # Slash commands
│   ├── hooks/             # Pre/post hooks
│   ├── settings.json      # Claude Code settings
│   └── statusline.sh      # Custom statusline
│
├── starship.toml          # Starship prompt configuration
│
└── tmux/
    └── .tmux.conf         # Tmux configuration (local only)
```

## What Gets Installed

### Essential Tools (All Environments)

- **fzf**: Fuzzy finder for files, history, and more
- **zoxide**: Smart directory jumping (replacement for cd)
- **ripgrep (rg)**: Fast grep alternative
- **fd**: Fast find alternative
- **bat**: Cat with syntax highlighting
- **git-delta**: Beautiful git diffs
- **starship**: Cross-shell prompt
- **jq**: JSON processor

### Additional Tools (Local Workstations)

- **eza**: Modern ls replacement
- **lazygit**: Terminal UI for git
- **tmux**: Terminal multiplexer
- **htop/btop**: System monitoring
- **ncdu**: Disk usage analyzer
- **duf**: Modern df alternative
- **procs**: Modern ps alternative
- **dust**: Intuitive du alternative
- **sd**: Simpler sed alternative
- **direnv**: Per-directory environment variables

### Shell Completions (All Environments)

Comprehensive autocompletion support:
- **bash-completion**: Intelligent completions with colored output
- **zsh-autosuggestions**: Fish-style history-based suggestions
- **zsh-syntax-highlighting**: Real-time command validation
- **Auto-generated completions** for: git, docker, kubectl, gh, terraform, aws, poetry, cargo, and more

See [COMPLETIONS.md](COMPLETIONS.md) for detailed information.

## Key Features

### Git Aliases

The dotfiles include extensive git aliases for productivity:

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

# And many more! See shell/aliases.sh
```

### Shell Functions

Useful functions available in your shell:

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

Powerful fuzzy finding with keyboard shortcuts:

- **Ctrl+R**: Search command history
- **Ctrl+T**: Search files in current directory
- **Alt+C**: Search and cd into directories

### Zoxide (Smart CD)

Navigate directories intelligently:

```bash
z proj        # Jump to ~/projects
z doc down    # Jump to ~/Documents/downloads
zi            # Interactive directory selection
```

### Claude Code Integration

Comprehensive Claude Code setup included:

- **Agents**: Specialized sub-agents for code review, debugging, testing, refactoring, security audits
- **Commands**: Slash commands for common workflows (`/commit`, `/test`, `/debug`, `/refactor`, `/pr-create`)
- **Hooks**: Validation hooks for commit messages, code formatting, security checks

See `claude-code/` directory READMEs for full documentation.

### Intelligent Shell Completion

**Bash features:**
- Case-insensitive matching
- Colored file type indicators
- Immediate option display
- Typo tolerance

**Zsh features:**
- Visual menu selection (arrow keys)
- Fish-style autosuggestions from history
- Real-time syntax highlighting
- Fuzzy matching with typo correction
- Context-aware completions

**Test it:**
```bash
git che<Tab>              # Completes to "checkout"
git checkout <Tab>        # Lists all branches
docker <Tab>              # Shows all docker commands
kubectl get <Tab>         # Lists kubernetes resources
cd /u/l/b<Tab>           # Expands to /usr/local/bin (zsh)
```

For more details, see [COMPLETIONS.md](COMPLETIONS.md).

## Customization

### Local Overrides

Create local configuration files that won't be tracked in git:

```bash
~/.bashrc.local      # Local bash configuration
~/.zshrc.local       # Local zsh configuration
~/.exports.local     # Local environment variables
~/.gitconfig.local   # Local git configuration
```

### Adding Your Own Tools

Edit `install.sh` to add your preferred tools. The script detects:
- Operating system (macOS, Ubuntu, Debian, etc.)
- Environment type (local, devcontainer, codespaces)
- Available package managers (brew, apt, etc.)

## Environment Variables

Key environment variables set by these dotfiles:

```bash
EDITOR=nvim              # Or vim/vi
HISTSIZE=100000         # Large command history
FZF_DEFAULT_COMMAND     # Use fd/rg for fzf
BAT_THEME=OneHalfDark   # Dark theme for bat
```

See `shell/exports.sh` for the complete list.

## Tmux Usage

If you're on a local machine (tmux is skipped in containers):

```bash
# Start new session
tmux

# Detach: Ctrl+a, d
# List sessions: tmux ls
# Attach: tmux attach -t <name>

# Split panes
# Horizontal: Ctrl+a, |
# Vertical: Ctrl+a, -

# Navigate panes: Alt+Arrow keys
# Resize panes: Ctrl+a, H/J/K/L
```

## Starship Prompt

The prompt shows:
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

**Bash:**
```bash
# Check if bash-completion is loaded
type _completion_loader

# Reload completions
source ~/.bashrc
```

**Zsh:**
```bash
# Rebuild completion cache
rm ~/.zcompdump*
exec zsh

# Test completions
git che<Tab>  # Should complete to "checkout"
```

See [COMPLETIONS.md](COMPLETIONS.md) for detailed troubleshooting.

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

## Contributing

Feel free to fork and customize for your own use! Some ideas:

- Add your favorite tools to `install.sh`
- Create language-specific configurations
- Add custom prompts or themes
- Share useful functions and aliases

## Resources

- [Dotfiles Guide](https://dotfiles.github.io/) - Your unofficial guide to dotfiles on GitHub
- [Starship Documentation](https://starship.rs/)
- [FZF GitHub](https://github.com/junegunn/fzf)
- [Zoxide GitHub](https://github.com/ajeetdsouza/zoxide)
- [VS Code Dotfiles Guide](https://code.visualstudio.com/docs/remote/containers#_personalizing-with-dotfile-repositories)

## License

MIT License - Feel free to use and modify!

## Credits

Inspired by various dotfiles repositories and the amazing CLI tool community.