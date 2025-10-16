# Shell Completions Guide

This dotfiles repository includes comprehensive shell completion support for both Bash and Zsh. Completions provide intelligent autocomplete for commands, options, file paths, and context-aware suggestions.

## Overview

- **Bash**: Uses bash-completion v2 with custom completions
- **Zsh**: Uses zinit plugin manager with zsh-autosuggestions and zsh-syntax-highlighting
- **Auto-generated**: Completions for 20+ modern CLI tools

## Bash Completions

### Features

- **Intelligent matching**: Case-insensitive, typo-tolerant completions
- **Colored output**: File types shown with colors
- **Immediate display**: Options displayed without double-tab
- **Context-aware**: Different completions based on command context

### How It Works

Bash completions are loaded from multiple sources:

1. **System completions**: `/usr/share/bash-completion/`
2. **Custom completions**: `~/.local/share/bash-completion/completions/`
3. **Tool-specific completions**: Generated during installation

### Supported Tools

Completions are automatically configured for:

- **git**: Branch names, subcommands, options
- **docker**: Containers, images, commands
- **kubectl**: Resources, contexts, namespaces
- **gh** (GitHub CLI): Repositories, PRs, issues
- **terraform**: Resources, commands
- **aws**: Services, commands
- And more...

### Testing Bash Completions

```bash
# Test basic completion
git che<Tab>              # Should complete to "checkout"

# Test branch completion
git checkout <Tab>        # Lists all branches

# Test file completion
cat <Tab>                 # Lists files with colors

# Test command completion
docker <Tab>              # Shows docker subcommands
```

### Troubleshooting Bash

**Completions not working:**

```bash
# Check if bash-completion is loaded
type _completion_loader

# Expected output: _completion_loader is a function

# If not loaded, reload bashrc
source ~/.bashrc
```

**Slow completions:**

```bash
# Clear completion cache
rm -rf ~/.cache/bash-completion

# Reload shell
exec bash
```

**Missing tool completions:**

```bash
# Manually generate completion
gh completion -s bash > ~/.local/share/bash-completion/completions/gh
source ~/.bashrc
```

## Zsh Completions

### Features

- **Visual menu selection**: Navigate completions with arrow keys
- **Fish-style autosuggestions**: Suggestions from command history
- **Real-time syntax highlighting**: Validates commands as you type
- **Fuzzy matching**: Matches with typos (e.g., `cd /u/l/b<Tab>` → `/usr/local/bin`)
- **Context-aware**: Different completions based on command position

### How It Works

Zsh uses the zinit plugin manager to load:

1. **fast-syntax-highlighting**: Real-time command validation
2. **zsh-autosuggestions**: History-based suggestions (accept with →)
3. **zsh-completions**: Extended completion definitions
4. **Custom completions**: Tool-specific completions in `~/.config/zsh/completions/`

### Plugins

**zsh-autosuggestions**:
- Suggests commands from history as you type
- Accept suggestion: Right arrow or `Ctrl+→`
- Accept word: `Alt+→`

**fast-syntax-highlighting**:
- Green: Valid command
- Red: Invalid command or not found
- Blue: Command option
- Yellow: Path

### Supported Tools

Same as Bash, plus additional zsh-specific completions:

- Enhanced git completion with branch descriptions
- Docker completion with container states
- Kubernetes completion with resource details
- And all tools that provide zsh completions

### Testing Zsh Completions

```bash
# Test menu selection
git checkout <Tab>        # Arrow keys to navigate

# Test fuzzy matching
cd /u/l/b<Tab>           # Expands to /usr/local/bin

# Test autosuggestions
git st                    # Shows "git status" in gray (if in history)
# Press → to accept

# Test syntax highlighting
git statuss               # Command appears red (invalid)
git status                # Command appears green (valid)
```

### Troubleshooting Zsh

**Completions not working:**

```bash
# Rebuild completion cache
rm ~/.zcompdump*
rm -rf ~/.cache/zsh/zcompcache
exec zsh
```

**Autosuggestions not appearing:**

```bash
# Check if plugin is loaded
echo $ZSH_AUTOSUGGEST_VERSION

# If empty, reinstall zinit plugins
rm -rf ~/.local/share/zinit
exec zsh
```

**Slow startup:**

```bash
# Profile zsh startup
zsh -xv 2>&1 | ts -i '%.s' | head -100

# Common causes:
# - Too many completions generated
# - Slow network calls in initialization
# - Large history file
```

**Syntax highlighting not working:**

```bash
# Check if plugin is loaded
echo $ZSH_HIGHLIGHT_VERSION

# Reinstall if needed
rm -rf ~/.local/share/zinit/plugins/zdharma-continuum---fast-syntax-highlighting
exec zsh
```

## Tool-Specific Completions

### Git

```bash
git <Tab>                 # All git commands
git checkout <Tab>        # Branches
git add <Tab>             # Modified files
git log --<Tab>           # Options
```

### Docker

```bash
docker <Tab>              # Docker commands
docker ps <Tab>           # Container options
docker exec <Tab>         # Running containers
docker run <Tab>          # Images
```

### Kubernetes

```bash
kubectl <Tab>             # Kubernetes commands
kubectl get <Tab>         # Resource types
kubectl get pods <Tab>    # Pod names
kubectl -n <Tab>          # Namespaces
```

### GitHub CLI

```bash
gh <Tab>                  # GitHub commands
gh pr <Tab>               # PR commands
gh pr checkout <Tab>      # Open PRs
gh repo <Tab>             # Repository commands
```

## FZF Integration

The dotfiles include FZF (fuzzy finder) integration with custom key bindings:

### Key Bindings

- **Ctrl+R**: Search command history with fuzzy matching
- **Ctrl+T**: Search files in current directory
- **Alt+C**: Search and cd into directories

### Examples

```bash
# Search history
<Ctrl+R>
# Type partial command, fuzzy match, Enter to execute

# Find and insert file path
cat <Ctrl+T>
# Type partial filename, Enter to insert

# Jump to directory
<Alt+C>
# Type partial directory name, Enter to cd
```

### FZF with Completions

FZF enhances completions for certain commands:

```bash
# Git branch selection with preview
git checkout **<Tab>

# Process kill with search
kill -9 **<Tab>

# SSH host selection
ssh **<Tab>

# Environment variable
export **<Tab>
```

## Custom Completions

### Adding Your Own

**Bash**:

```bash
# Create completion file
~/.local/share/bash-completion/completions/mycommand

# Add completion function
_mycommand() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="--help --version start stop restart"

    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}
complete -F _mycommand mycommand
```

**Zsh**:

```zsh
# Create completion file
~/.config/zsh/completions/_mycommand

# Add completion function
#compdef mycommand

_mycommand() {
    local -a commands
    commands=(
        'start:Start the service'
        'stop:Stop the service'
        'restart:Restart the service'
    )
    _describe 'command' commands
}

_mycommand "$@"
```

## Performance Tips

### Bash

1. **Lazy loading**: Heavy completions loaded on demand
2. **Caching**: Completion results cached when possible
3. **Minimal generation**: Only generate needed completions

### Zsh

1. **Compile completions**: `zcompile ~/.zshrc`
2. **Use zinit turbo mode**: Async plugin loading
3. **Limit completion cache size**: Keep cache under 10MB

## Completion Styles

### Zsh Completion Styles

Customize completion behavior in `~/.zshrc.local`:

```zsh
# Menu selection
zstyle ':completion:*' menu select

# Grouping
zstyle ':completion:*' group-name ''

# Colors
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Case sensitivity
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Partial completion
zstyle ':completion:*' complete-options true
```

## Resources

- [Bash Completion Project](https://github.com/scop/bash-completion)
- [Zsh Completion System](https://zsh.sourceforge.io/Doc/Release/Completion-System.html)
- [zinit Plugin Manager](https://github.com/zdharma-continuum/zinit)
- [FZF Documentation](https://github.com/junegunn/fzf)

## Getting Help

If completions aren't working:

1. Run the test script: `~/.dotfiles/tests/test-install.sh`
2. Check shell startup: `bash -x ~/.bashrc` or `zsh -x ~/.zshrc`
3. Verify tool installation: `command -v <tool>`
4. Review completion files: `ls ~/.local/share/bash-completion/completions/`
5. Check zinit status: `zinit report --all` (zsh only)
