# Tooling

Full CLI inventory, shell configuration, and git configuration installed by
this repo. For installation toggles and override files, see
[`customization.md`](customization.md).

## CLI tools

On Linux, most tools come from GitHub releases with checksum verification
(musl-static builds for portability). On macOS, Homebrew handles everything.

### Core tools (installed everywhere)

| Tool                                                           | Purpose                                              |
|----------------------------------------------------------------|------------------------------------------------------|
| [fzf](https://github.com/junegunn/fzf)                         | Fuzzy finder for files, history, etc.                |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`)        | Fast regex search across files                       |
| [fd](https://github.com/sharkdp/fd)                            | Fast file finder                                     |
| [bat](https://github.com/sharkdp/bat)                          | Cat with syntax highlighting                         |
| [jq](https://github.com/jqlang/jq)                             | JSON processor                                       |
| [starship](https://starship.rs/)                               | Cross-shell prompt with git status                   |
| [zoxide](https://github.com/ajeetdsouza/zoxide)                | Smart directory jumping (replaces `cd`)              |
| [eza](https://github.com/eza-community/eza)                    | Modern `ls` with git integration                     |
| [git-delta](https://github.com/dandavison/delta)               | Syntax-highlighted git diffs                         |
| [sd](https://github.com/chmln/sd)                              | Find-and-replace (modern sed, PCRE regex)            |
| [scc](https://github.com/boyter/scc)                           | Fast code statistics (LOC, complexity)               |
| [yq](https://github.com/mikefarah/yq)                          | YAML/TOML/XML editor (preserves comments)            |
| [watchexec](https://github.com/watchexec/watchexec)            | File watcher for auto-test/rebuild                   |
| [gitleaks](https://github.com/gitleaks/gitleaks)               | Secret scanner (pre-commit hook)                     |
| [shellcheck](https://github.com/koalaman/shellcheck)           | Shell script linter                                  |
| [atuin](https://github.com/atuinsh/atuin)                      | Shell history with SQLite + context search           |
| [duf](https://github.com/muesli/duf)                           | Modern disk-free utility                             |
| [dust](https://github.com/bootandy/dust)                       | Intuitive disk usage (modern `du`)                   |
| [procs](https://github.com/dalance/procs)                      | Modern process viewer with color and search          |
| [hyperfine](https://github.com/sharkdp/hyperfine)              | CLI benchmarking tool                                |
| [yazi](https://github.com/sxyazi/yazi)                         | Terminal file manager with async I/O                 |
| [carapace](https://github.com/carapace-sh/carapace-bin)        | Unified shell completions for 500+ tools             |

### Agentic tools (installed in devcontainers, deeply configured)

| Tool                                                           | Purpose                                              |
|----------------------------------------------------------------|------------------------------------------------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code)  | AI coding assistant CLI                              |
| [Codex CLI](https://github.com/openai/codex)                   | AI coding assistant CLI                              |
| [ast-grep](https://ast-grep.github.io/) (`sg`)                 | Structural code search by AST                        |
| [difftastic](https://github.com/Wilfred/difftastic) (`difft`)  | AST-aware file diff                                  |

Skip with `DOTFILES_NO_AI_TOOLS=1`.

### Optional tools (hosts only)

| Tool                                                           | Purpose                                              |
|----------------------------------------------------------------|------------------------------------------------------|
| [lazygit](https://github.com/jesseduffield/lazygit)            | Terminal UI for git                                  |
| [bottom](https://github.com/ClementTsang/bottom) (`btm`)       | System monitor                                       |
| [mise](https://mise.jdx.dev/)                                  | Runtime version manager (asdf/nvm/pyenv replacement) |

### Developer preferences (config only, NOT installed)

The repo supplies aliases, completions, state persistence, and shell
integration; projects bring the executable.

| Tool                                                           | What this repo provides                                                 |
|----------------------------------------------------------------|-------------------------------------------------------------------------|
| [gh](https://cli.github.com/)                                  | Completions, `~/.config/gh` state persistence, `ghpr` function          |
| [glab](https://gitlab.com/gitlab-org/cli)                      | Completions, `~/.config/glab-cli` state persistence, `glmr` function    |
| [docker](https://www.docker.com/)                              | Aliases (`d`, `dc`, `dps`, `di`, `dex`) + helper functions              |
| [kubectl](https://kubernetes.io/)                              | Aliases (`k`, `kgp`, `kgs`, `kgd`), completions                         |
| [direnv](https://direnv.net/)                                  | Shell activation (deferred on zsh for performance)                      |
| [uv](https://docs.astral.sh/uv/)                               | Aliases (`uvr`, `uvs`, `uva`)                                           |
| [xh](https://github.com/ducaale/xh)                            | Aliases (`http`, `https`)                                               |

## Shell configuration

### Aliases (`shell/aliases.sh`)

80+ aliases for git, docker, kubernetes, python, navigation, and modern tool
replacements. Core utilities like `grep` and `find` are **not** shadowed by
default; set `DOTFILES_OPINIONATED_ALIASES=1` to enable `grep`->`rg` and
`find`->`fd`.

### Functions (`shell/functions.sh`)

25+ utility functions including:

- `mkcd <dir>` -- make and cd
- `extract <archive>` -- unpack any common archive format
- `killport <port>` -- kill the process listening on a port
- `gcof` -- fzf branch picker
- `glf` -- fzf git log browser
- `serve [port]` -- quick HTTP server on the cwd
- `y` -- yazi with cd-on-exit
- `dotfiles-doctor` -- installation health check
- `cat` -- uses `bat` in terminals, plain `cat` in pipes (transparent fallback)

### Environment (`shell/exports.sh`)

XDG base directory compliance, large history (100K entries), fzf with
TokyoNight theme, bat/eza/ripgrep themes, editor preference chain
(nvim > vim > vi), Docker BuildKit enabled.

### Performance

zsh startup is optimized:

- `compinit` rebuilds at most once per day, not every shell start.
- zoxide and direnv initialize on first prompt (deferred via `precmd`), not
  during startup.
- `ZSH_PROFILE=1 zsh -i -c exit` shows where time is spent (`zprof` output).
- CI builds log per-component timing automatically.

## Git configuration

Three config files, each with a distinct role:

| File                          | Purpose                                                   | Managed by                   |
|-------------------------------|-----------------------------------------------------------|------------------------------|
| `~/.gitconfig`                | User identity (name, email, signing key)                  | You (or VS Code / Codespaces)|
| `~/.config/git/config`        | XDG config; contains `[include]` pointing at dotfiles     | `install.sh`                 |
| `git/.gitconfig` (this repo)  | Shared settings: delta, aliases, hooks, merge, rebase     | This repo                    |

`install.sh` prepends an `[include]` directive to `~/.config/git/config` that
pulls in `git/.gitconfig` from this repo. Git reads configs in order
(`~/.gitconfig` first, then `~/.config/git/config`); later values override
earlier ones. Result: personal identity in `~/.gitconfig` is untouched, while
dotfiles settings (delta, aliases, hooks) come via the include.

The XDG config file is a real file (not a symlink), so `git config --global`
writes go there safely without dirtying the dotfiles repo. Legacy symlinks
from older versions are migrated automatically.

### Delta integration

Syntax-highlighted diffs with line numbers, side-by-side optional, OneHalfDark
theme.

### Git aliases

44 aliases covering every common operation: `gs` = status, `gl` = log graph,
`gd` = diff, `gpf` = push --force-with-lease, etc. Full list: `git aliases`.

### Conventional commits (enforced globally)

The `commit-msg` global hook enforces:

- `type(scope): description` format (feat, fix, refactor, docs, test, ...)
- Minimum 10-character subject
- Blocks AI tool attribution and `Co-Authored-By` lines
- Blocks emoji characters in commit messages
- Merge commits pass through unchanged
- Per-repo customization via `.git/hooks/commit-msg.local`

### SSH commit signing

The installer auto-detects SSH keys from the agent (prefers ed25519) or from
`~/.ssh/id_ed25519.pub`. When a key is found, `commit.gpgsign` is enabled
and `allowed_signers` is populated. No key? Signing stays disabled.

Inside devcontainers the agent is the only accepted source: a file-based key
would be a long-lived signing credential persisted across rebuilds, so it is
deliberately not adopted there. Forward ssh-agent into the container instead.

Note on signing inside the sandbox on Linux/WSL2 hosts: agent-based signing
works unless Claude Code's optional AF_UNIX seccomp filter
(`@anthropic-ai/sandbox-runtime`) is installed, which this repo does not
install. File-based signing works either way. See
[sandbox.md](sandbox.md#ssh-agent-and-signed-commits) for how to check which
case you are in and what the tradeoff is.

### Secret scanning

gitleaks runs as a global `pre-commit` hook, scanning staged changes for API
keys, passwords, and tokens. Silently passes if gitleaks is not installed.
Per-repo hooks via `.git/hooks/pre-commit.local`.

The global `pre-push` dispatcher scans every outgoing commit range as a second
checkpoint, chains Git LFS, and delegates to `.git/hooks/pre-push.local`.
Local hooks are bypassable; forge push protection and repository rulesets are
the authoritative team-level controls.

## Prompt and tool configuration

### Starship (`config/starship.toml`)

Two-line prompt showing username, directory (truncated to repo), git branch
with status indicators (ahead/behind/conflicts/stashed/modified/staged),
language versions (Python, Node, Rust, Go, Java, Ruby), Docker context, and
command duration.

### Ripgrep (`config/ripgrep/config`)

Follows symlinks, searches hidden files, excludes `.git`, smart-case matching,
sorted by path, colored output.
