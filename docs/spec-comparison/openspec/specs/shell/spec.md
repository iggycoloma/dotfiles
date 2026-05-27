# shell

## Overview

Bash and zsh runtime configuration: rc files, aliases, functions, exports, completions, and lazy-init.
Optimized for fast interactive startup.
Provides machine-specific override hooks (`*.local` files) so users can layer customizations without forking the dotfiles.

## Requirements

### Shell rc files

- The installer MUST symlink `~/.bashrc`, `~/.bash_profile`, `~/.zshrc`, and `~/.zprofile` to the corresponding files in `shell/`.
- `~/.bashrc` MUST be sourceable from `~/.bash_profile` so login shells get the same config.
- The shell rc files MUST source `aliases.sh`, `functions.sh`, `exports.sh`, and `completion.sh` from the dotfiles repo.

### Aliases

- The deployed `aliases.sh` MUST define at least 80 aliases covering git, docker, kubernetes, python, navigation, and modern-tool replacements.
- `grep` and `find` MUST NOT be aliased to `rg` and `fd` by default.
- When `DOTFILES_OPINIONATED_ALIASES=1` is set, `grep` MUST be aliased to `rg` and `find` MUST be aliased to `fd`.
- Aliases for tools that are not installed MUST be defined unconditionally ("command not found" on use is acceptable).

### Functions

- `functions.sh` MUST define at least 25 utility functions including: `mkcd`, `extract`, `killport`, `gcof` (fzf branch picker), `glf` (fzf git log), `dotfiles-doctor`, `serve`, `y` (yazi with cd-on-exit), and a smart `cat` that uses `bat` in a TTY and plain `cat` in pipes.
- Functions MUST NOT pollute the namespace with helper variables (use locals).

### Exports / environment

- `exports.sh` MUST set XDG base directory variables, `HISTSIZE=100000`, `EDITOR` (preferring nvim > vim > vi), `FZF_DEFAULT_COMMAND` to use `fd` with hidden files and `.git` exclusion, `FZF_DEFAULT_OPTS` with the TokyoNight theme, `BAT_THEME=OneHalfDark`, and `DOCKER_BUILDKIT=1`.
- `exports.sh` MUST set `CLAUDE_CONFIG_DIR=$HOME/.claude`.

### Local override files

- The shell rc files MUST source any of `~/.bashrc.local`, `~/.zshrc.local`, `~/.exports.local`, `~/.aliases.local`, `~/.functions.local` if present.
- These files MUST be gitignored.

### zsh startup performance

- `compinit` MUST rebuild its cache no more than once per day.
  The compiled dump MUST live under `~/.cache/zsh/zcompdump-*`.
- zoxide and direnv hooks MUST initialize on first prompt (deferred via `precmd`), not during shell startup.
- `ZSH_PROFILE=1` MUST enable `zprof` output for cold-start profiling.
- Interactive zsh startup time SHOULD be under 200ms on a warm cache; CI builds SHOULD log per-component timing.

### Completions

- `completion.sh` MUST initialize completions for fzf, zoxide, atuin, and direnv when those tools are present.
- carapace MUST be initialized when present, providing completions for 500+ tools.

## Scenarios

### Scenario: Fresh shell startup uses cached compinit

GIVEN a zsh shell where `~/.cache/zsh/zcompdump-*.zwc` exists from earlier today
WHEN the user starts a new interactive shell
THEN compinit reads the cached dump
AND does NOT rescan `$fpath`
AND the prompt appears in under 200ms.

### Scenario: zoxide initializes lazily

GIVEN a zsh shell that just started
WHEN the prompt is rendered for the first time
THEN `zoxide init` runs in `precmd`
AND subsequent prompts skip the init
AND `z`, `zi`, `zoxide` commands work normally.

### Scenario: Opinionated aliases respected

GIVEN `DOTFILES_OPINIONATED_ALIASES=1` is exported in `~/.exports.local`
WHEN the user runs `grep foo file.txt`
THEN the alias resolves to `rg foo file.txt`
AND `\grep` (escaped) still invokes the system grep.

### Scenario: Local override layered on top

GIVEN `~/.aliases.local` defines `alias k='kubectl'`
WHEN `~/.bashrc` is sourced
THEN `~/.aliases.local` loads after `aliases.sh`
AND `k` is defined as `kubectl`
AND `k` overrides any earlier definition from `aliases.sh`.

## Non-Behavior

- The shell config does NOT shadow `grep` or `find` by default (opt-in only).
- The shell config does NOT install plugins or plugin managers (no oh-my-zsh, no zinit-managed plugins by default; carapace and zinit are used only for completions).
- The shell config does NOT manage Python, Node, or Rust toolchain versions (mise/asdf is opt-in via the developer-preferences tier).
- The shell config does NOT touch `/etc/profile.d/` or system-wide bash config; everything is per-user.
- The shell config does NOT set `EDITOR=code` even in VS Code; the fallback chain stays nvim > vim > vi for predictable headless behavior.
