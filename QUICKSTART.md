# Quick Start Guide

Get up and running with these dotfiles in minutes.

## For VS Code Devcontainers/Codespaces

### One-Time Setup

1. **Fork this repository** to your GitHub account

2. **Configure VS Code**:
   - Open Settings (`Cmd/Ctrl + ,`)
   - Search for "dotfiles"
   - Set these values:
     - **Dotfiles: Repository**: `yourusername/dotfiles`
     - **Dotfiles: Target Path**: `~/dotfiles` (default)
     - **Dotfiles: Install Command**: `install.sh` (default)

3. **Done!** Your dotfiles will automatically install in every new devcontainer/Codespace

### Test It

1. Create or reopen a devcontainer
2. Wait for automatic installation (2-3 minutes)
3. Open terminal - you should see the Starship prompt
4. Try commands:
   ```bash
   gs              # git status (alias)
   ll              # eza listing (if installed)
   z <dir>         # zoxide jump (after visiting directories)
   fzf             # fuzzy finder
   ```

## For Local Machine

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles

# Run installation
cd ~/.dotfiles
chmod +x install.sh
./install.sh
```

Installation takes 5-15 minutes depending on internet speed.

### Post-Installation

1. **Reload your shell**:
   ```bash
   exec bash
   # or
   exec zsh
   ```

2. **Configure Git**:
   ```bash
   cp ~/.dotfiles/.gitconfig.local.example ~/.gitconfig.local
   # Edit with your details
   nano ~/.gitconfig.local
   ```

3. **Test it**:
   ```bash
   gs              # git status
   ll              # eza listing
   z ~             # zoxide jump
   Ctrl+R          # fzf history search
   ```

## Essential Commands

### Git Aliases

```bash
gs              # git status -sb
ga              # git add
gc              # git commit -v
gp              # git push
gpl             # git pull
gco             # git checkout
gcb             # git checkout -b
gl              # git log (pretty)
gd              # git diff
lg              # lazygit (if installed)
```

### Directory Navigation

```bash
..              # cd ..
...             # cd ../..
z <partial>     # Jump to frecent directory
zi              # Interactive directory selection
```

### File Operations

```bash
ll              # List files (eza)
la              # List all files
lt              # Tree view
cat <file>      # Show file (bat with syntax highlighting)
```

### Search

```bash
Ctrl+R          # Search command history (fzf)
Ctrl+T          # Find files (fzf)
Alt+C           # Change directory (fzf)
rg <pattern>    # Search file contents (ripgrep)
fd <name>       # Find files by name
```

### Useful Functions

```bash
mkcd <dir>              # Create and enter directory
extract <archive>       # Extract any archive format
killport <port>         # Kill process on port
serve [port]            # HTTP server for current dir
weather [location]      # Get weather
backup <file>           # Create timestamped backup
```

## Customization

### Local Configuration Files

Create these files for personal customizations (not tracked in git):

```bash
~/.bashrc.local         # Local bash configuration
~/.zshrc.local          # Local zsh configuration
~/.gitconfig.local      # Local git configuration
~/.exports.local        # Local environment variables
~/.aliases.local        # Local aliases
~/.functions.local      # Local functions
```

### Example: Add Custom Alias

```bash
# Add to ~/.aliases.local
echo "alias myproject='cd ~/code/my-project'" >> ~/.aliases.local

# Reload shell
source ~/.bashrc
```

### Example: Add Environment Variable

```bash
# Add to ~/.exports.local
echo 'export MYVAR="value"' >> ~/.exports.local

# Reload shell
source ~/.bashrc
```

## Switching Shells

### Switch to Zsh

```bash
# Install zsh if needed
sudo apt install zsh

# Change default shell
chsh -s $(which zsh)

# Logout and login (or restart terminal)
```

### Switch to Bash

```bash
# Change default shell
chsh -s $(which bash)

# Logout and login (or restart terminal)
```

Both shells work with these dotfiles!

## Updating

```bash
cd ~/.dotfiles
git pull
./install.sh
source ~/.bashrc  # or ~/.zshrc
```

The install script is idempotent - safe to run multiple times.

## Troubleshooting

### Tools not found

```bash
# Check PATH includes ~/.local/bin
echo $PATH | grep ".local/bin"

# If not, reload shell
source ~/.bashrc
```

### Completions not working

**Bash**:
```bash
source ~/.bashrc
type _completion_loader  # Should be a function
```

**Zsh**:
```bash
rm ~/.zcompdump*
exec zsh
```

### Starship prompt not showing

```bash
# Check if starship is installed
which starship

# If not, install manually
curl -sS https://starship.rs/install.sh | sh
```

### Run tests

```bash
~/.dotfiles/tests/test-install.sh
```

## Advanced Features

### FZF Git Integration

```bash
gcof            # Checkout git branch with fuzzy search
glf             # Git log with fuzzy search and preview
```

### Docker Helpers

```bash
dps             # docker ps
dex <container> # docker exec -it <container> /bin/bash
dlogs           # Select container and tail logs (fzf)
dclean          # Clean up Docker resources
```

### Tmux (Host machines only)

```bash
tmux            # Start new session
Ctrl+a |        # Split horizontal
Ctrl+a -        # Split vertical
Ctrl+a d        # Detach
tmux attach     # Reattach
```

## Getting Help

- **Full documentation**: See README.md
- **Completions**: See COMPLETIONS.md
- **Architecture**: See ARCHITECTURE.md
- **Test installation**: `~/.dotfiles/tests/test-install.sh`

## Tips

1. **Learn FZF keybindings**: `Ctrl+R`, `Ctrl+T`, `Alt+C` will change your workflow
2. **Use zoxide**: After visiting directories, `z` becomes incredibly fast
3. **Explore aliases**: Run `alias` to see all available shortcuts
4. **Customize locally**: Use `.local` files to add personal configs
5. **Keep updated**: `cd ~/.dotfiles && git pull && ./install.sh`

Happy coding! 🚀
