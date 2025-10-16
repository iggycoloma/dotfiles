# Dotfiles Architecture

This document explains the design decisions, architecture, and technical implementation of this dotfiles repository.

## Design Philosophy

### Core Principles

1. **Devcontainer-First**: Optimized for VS Code devcontainers and GitHub Codespaces
2. **Idempotent**: Can be run multiple times safely without side effects
3. **Modular**: Shell configurations are broken into logical, reusable components
4. **Environment-Aware**: Detects and adapts to container vs host environments
5. **Fast**: Minimal startup time, especially in containers (<100ms target)
6. **XDG-Compliant**: Uses XDG Base Directory specification where practical

### Key Design Decisions

**Why Symlinks over Copying?**
- Changes to dotfiles repo immediately reflect in shell
- Easy to track what's managed by dotfiles
- Simple to update: git pull + source shell

**Why Bootstrap Scripts?**
- Separation of concerns (detection, packages, symlinks, completions)
- Can be run independently for testing/debugging
- Easy to add new installation logic
- Modular and maintainable

**Why Minimal Container Install?**
- Faster container startup (2-3 min vs 10+ min)
- Most devcontainers are ephemeral
- Core tools are sufficient for most dev work
- Host machines get full suite

## Repository Structure

```
~/.dotfiles/
├── install.sh              # Main entry point (VS Code compatible)
├── README.md              # User-facing documentation
├── ARCHITECTURE.md        # This file
├── COMPLETIONS.md         # Completion system documentation
│
├── bootstrap/             # Installation logic
│   ├── detect.sh         # Environment & OS detection
│   ├── packages.sh       # Package installation
│   ├── symlinks.sh       # Symlink management
│   └── completions.sh    # Completion setup
│
├── shell/                # Shell configurations
│   ├── .bashrc           # Bash entry point
│   ├── .zshrc            # Zsh entry point
│   ├── .bash_profile     # Bash login shell
│   ├── .zprofile         # Zsh login shell
│   ├── aliases.sh        # Shared aliases
│   ├── functions.sh      # Shared functions
│   ├── exports.sh        # Environment variables
│   └── completion.sh     # Completion initialization
│
├── git/                  # Git configuration
│   ├── .gitconfig        # Main git config
│   ├── .gitignore_global # Global gitignore
│   └── .gitmessage       # Commit template
│
├── config/               # XDG-style configs
│   ├── starship.toml     # Starship prompt
│   ├── bat/              # Bat themes/config
│   ├── bottom/           # Bottom config
│   └── lazygit/          # Lazygit config
│
├── tmux/                 # Tmux (host-only)
│   └── .tmux.conf
│
├── vim/                  # Vim config
│   └── .vimrc
│
├── bin/                  # Custom scripts
│
└── tests/                # Validation tests
    └── test-install.sh
```

## Bootstrap System

### Detection (detect.sh)

**Purpose**: Identify environment, OS, and available tools

**Functions**:
- `detect_environment()`: Identifies codespaces, devcontainer, remote, or local
- `detect_os()`: Determines Linux distro or macOS
- `detect_package_manager()`: Finds apt, brew, dnf, or pacman
- `is_minimal_install()`: Returns true for containers
- `has_tool()`: Checks if command exists

**Environment Detection Logic**:

```bash
if [[ -n "${CODESPACES}" ]]; then
    # GitHub Codespaces
elif [[ -n "${REMOTE_CONTAINERS}" ]]; then
    # VS Code devcontainer
elif [[ -n "${SSH_CONNECTION}" ]]; then
    # Remote via SSH
else
    # Local machine
fi
```

### Packages (packages.sh)

**Purpose**: Install CLI tools based on environment

**Strategy**:
1. Detect environment (minimal vs full)
2. Install base packages via system package manager
3. Install modern tools from GitHub releases for latest versions
4. Create symlinks for aliased commands (bat/batcat, fd/fdfind)

**Tool Categories**:

**Core (All Environments)**:
- fzf, ripgrep, fd, bat, jq
- Installed via apt/brew first, then GitHub if not available

**Modern (GitHub Releases)**:
- eza, zoxide, starship, delta
- Always from GitHub for latest versions
- Faster than compiling, more up-to-date than apt

**Host-Only**:
- lazygit, bottom, tmux, htop, ncdu
- Skipped in containers for faster installation

**Installation Flow**:

```
detect_environment() → minimal or full
  ↓
install via package manager (apt/brew)
  ↓
install from GitHub releases (parallel)
  ↓
create ~/.local/bin symlinks
```

### Symlinks (symlinks.sh)

**Purpose**: Link dotfiles to home directory

**Strategy**:
1. Backup existing files to `~/.dotfiles_backup_TIMESTAMP/`
2. Create symlinks from repo to home
3. Handle XDG-compliant locations (`~/.config/`)
4. Skip container-inappropriate files (tmux in containers)

**Symlink Mapping**:

```
$DOTFILES_DIR/shell/.bashrc       → ~/.bashrc
$DOTFILES_DIR/shell/.zshrc        → ~/.zshrc
$DOTFILES_DIR/git/.gitconfig      → ~/.gitconfig
$DOTFILES_DIR/config/starship.toml → ~/.config/starship.toml
```

**Backup Strategy**:
- Only backs up real files, not existing symlinks
- Timestamped backups prevent overwriting
- User can restore from backup if needed

### Completions (completions.sh)

**Purpose**: Set up shell completion systems

**Bash Strategy**:
1. Load system bash-completion if available
2. Generate tool-specific completions
3. Store in `~/.local/share/bash-completion/completions/`
4. Source from `.bashrc`

**Zsh Strategy**:
1. Install zinit plugin manager
2. Install completion plugins (autosuggestions, syntax-highlighting)
3. Generate tool completions
4. Store in `~/.config/zsh/completions/`
5. Initialize completion system in `.zshrc`

**Plugin Management**:
- zinit for zsh (lightweight, fast, turbo mode support)
- No plugin manager for bash (uses native bash-completion)

## Shell Configuration

### Loading Order

**Bash**:
```
.bash_profile (login shell)
  └── sources .bashrc
      └── sources modular configs
          ├── exports.sh
          ├── aliases.sh
          ├── functions.sh
          └── completion.sh
```

**Zsh**:
```
.zprofile (login shell)
  └── sources .zshrc
      └── sources modular configs
          ├── exports.sh
          ├── aliases.sh
          ├── functions.sh
          └── completion.sh
```

### Modular Configuration

**Why Shared Configs?**
- DRY principle: aliases/functions defined once
- Shell-agnostic for most features
- Easy to maintain and test
- Consistent experience across shells

**Shell-Specific Parts**:
- History handling (different options)
- Completion system (completely different)
- Prompt (if starship not available)
- Key bindings

### Performance Optimization

**Lazy Loading**:
- Heavy completions loaded on-demand
- Plugins loaded asynchronously (zsh)
- Tool initialization deferred when possible

**Startup Time Targets**:
- Container: <100ms
- Host: <200ms
- Measured with: `time bash -i -c exit`

**Optimization Techniques**:
1. Minimize external command calls in shell init
2. Use built-in shell features over external commands
3. Cache completion results
4. Async plugin loading (zinit turbo mode)
5. Compile zsh configs with zcompile

## Git Configuration

### Structure

**Main Config** (`~/.gitconfig`):
- Includes sensible defaults
- Configures delta for diffs
- Sets up aliases
- Includes `~/.gitconfig.local` for user-specific settings

**Why Local Include?**
- User-specific: name, email, signing key
- Machine-specific: different work/personal credentials
- Not committed to repo
- Overrides defaults from main config

**Example `~/.gitconfig.local`**:
```ini
[user]
    name = Your Name
    email = your.email@example.com
    signingkey = ABC123

[github]
    user = yourusername
```

### Delta Integration

Git delta provides beautiful diffs with:
- Syntax highlighting
- Line numbers
- Side-by-side view (optional)
- Git integration for `diff`, `log`, `show`, `blame`

Automatically activated via core.pager setting.

## XDG Base Directory Compliance

### What is XDG?

XDG Base Directory Specification defines standard locations for:
- **Config**: `~/.config/` (XDG_CONFIG_HOME)
- **Data**: `~/.local/share/` (XDG_DATA_HOME)
- **Cache**: `~/.cache/` (XDG_CACHE_HOME)
- **State**: `~/.local/state/` (XDG_STATE_HOME)

### Implementation

**Compliant**:
- Starship: `~/.config/starship.toml`
- Bat: `~/.config/bat/`
- Zsh: `~/.config/zsh/`
- Completions: `~/.local/share/bash-completion/`

**Legacy (for compatibility)**:
- `.bashrc`, `.zshrc`: Traditional locations expected by shells
- `.gitconfig`: Git's default location

**Strategy**: Use XDG where supported, fallback to traditional locations for compatibility.

## Environment Variables

### Key Variables

**XDG**:
```bash
XDG_CONFIG_HOME=~/.config
XDG_DATA_HOME=~/.local/share
XDG_CACHE_HOME=~/.cache
XDG_STATE_HOME=~/.local/state
```

**Editor**:
```bash
EDITOR=nvim|vim|vi  # First available
VISUAL=$EDITOR
```

**FZF**:
```bash
FZF_DEFAULT_COMMAND  # Use fd/rg instead of find
FZF_DEFAULT_OPTS     # Theme and behavior
```

**History**:
```bash
HISTSIZE=100000      # Large in-memory history
HISTFILESIZE=100000  # Large history file
HISTCONTROL=ignoreboth:erasedups
```

### Local Overrides

Users can create `~/.exports.local` for:
- API keys
- Custom paths
- Environment-specific variables
- Private configurations

## Testing

### Test Script (test-install.sh)

**Purpose**: Validate installation success

**What It Tests**:
1. Repository structure exists
2. Bootstrap scripts exist
3. Configuration files exist
4. Symlinks point to correct targets
5. Core tools are installed
6. Shells start successfully
7. Environment variables are set
8. Git aliases work

**Usage**:
```bash
~/.dotfiles/tests/test-install.sh
```

**Exit Codes**:
- 0: All tests passed
- 1: Some tests failed

## VS Code Integration

### How It Works

1. User configures VS Code settings:
   ```json
   {
     "dotfiles.repository": "username/dotfiles",
     "dotfiles.targetPath": "~/dotfiles",
     "dotfiles.installCommand": "install.sh"
   }
   ```

2. VS Code clones repo to `~/dotfiles` (or custom path)

3. VS Code runs `install.sh`

4. Install script:
   - Detects devcontainer environment
   - Runs minimal installation
   - Creates symlinks
   - Sets up completions

5. User opens new terminal → dotfiles active

### Devcontainer-Specific Behavior

**Detected by**:
- `$CODESPACES` environment variable (Codespaces)
- `$REMOTE_CONTAINERS` environment variable (devcontainer)

**Optimizations**:
- Skip tmux (not needed in containers)
- Skip heavy tools (lazygit, bottom, etc.)
- Minimal package set for faster startup
- Pre-compiled binaries over compilation

## Maintenance

### Adding New Tools

1. Add to `bootstrap/packages.sh`:
   ```bash
   GITHUB_RELEASES["newtool"]="author/repo"
   ```

2. Add install function if needed

3. Add to aliases/functions if relevant

4. Update documentation

### Adding Aliases

1. Add to `shell/aliases.sh`
2. Source automatically in both shells
3. Test in both bash and zsh

### Updating Tools

```bash
cd ~/.dotfiles
git pull
./install.sh  # Re-runs installation (idempotent)
```

## Security Considerations

### What's Safe

- Public dotfiles (no secrets)
- Local override files (.local) for secrets
- Git config excludes common secret files
- No credentials committed

### Secrets Management

**Don't commit**:
- API keys
- Passwords
- Private keys
- Tokens

**Use instead**:
- `~/.exports.local` for environment variables
- `~/.gitconfig.local` for git credentials
- Secret managers (1Password, pass, etc.)
- `.envrc` with direnv (already in .gitignore)

## Future Enhancements

### Potential Additions

1. **Profiles**: Different tool sets (minimal, full, language-specific)
2. **Secrets**: Age-encrypted secrets with automatic decryption
3. **Private dotfiles**: Support for private repo overlay
4. **Update command**: `dotfiles-update` to pull and reinstall
5. **Devcontainer features**: Publish as devcontainer feature
6. **Neovim config**: Full Neovim setup (optional)
7. **Language toolchains**: Optional nvm, pyenv, rustup, etc.

## Performance Metrics

### Target Benchmarks

- **Container install**: <3 minutes
- **Host install**: <10 minutes
- **Bash startup**: <100ms
- **Zsh startup**: <150ms
- **Symlink creation**: <1 second
- **Completion generation**: <5 seconds

### Measuring Performance

```bash
# Install time
time ./install.sh

# Shell startup
time bash -i -c exit
time zsh -i -c exit

# Profile zsh startup
zsh -xv 2>&1 | ts -i '%.s'
```

## Troubleshooting

### Common Issues

**Symlinks not created**:
- Check `$DOTFILES_DIR` is set correctly
- Run `bootstrap/symlinks.sh` manually
- Check permissions on home directory

**Tools not found**:
- Ensure `~/.local/bin` is in PATH
- Run `bootstrap/packages.sh` manually
- Check GitHub rate limiting

**Completions not working**:
- Reload shell: `exec bash` or `exec zsh`
- Check completion files exist
- See COMPLETIONS.md for detailed troubleshooting

**Slow shell startup**:
- Profile startup (see Performance Metrics)
- Disable unused plugins
- Check for network calls in init

## References

- [XDG Base Directory Spec](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
- [VS Code Dotfiles](https://code.visualstudio.com/docs/remote/containers#_personalizing-with-dotfile-repositories)
- [Bash Completion](https://github.com/scop/bash-completion)
- [Zsh Completion System](https://zsh.sourceforge.io/Doc/Release/Completion-System.html)
- [Starship Prompt](https://starship.rs/)
