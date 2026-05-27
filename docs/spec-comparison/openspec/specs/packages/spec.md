# packages

## Overview

CLI-tool installation logic that adapts to the available package manager.
Linux installs prefer GitHub releases (musl-static) with SHA-256 verification
for tools where the distro package is stale or missing; macOS uses Homebrew
exclusively. Falls back to `apt`/`apk` packages where they meet quality bars.

## Requirements

### Tool tiers

- **Core tools** MUST install on every supported environment (host,
  devcontainer, Codespaces, all OSes): fzf, ripgrep, fd, bat, jq, starship,
  zoxide, eza, git-delta, sd, scc, yq, watchexec, gitleaks, shellcheck, atuin,
  duf, dust, procs, hyperfine, yazi, carapace.
- **Agentic tools** MUST install in devcontainers and Codespaces (default-on
  there) and MUST be skippable on hosts: Claude Code, Codex CLI, ast-grep,
  difftastic.
- **Optional tools** SHOULD install on hosts and SHOULD be skipped in
  CI/lightweight environments: lazygit, bottom, mise.

### Host sandbox prerequisites

- On Linux hosts, the installer MUST install both `bubblewrap` and
  `socat` as a pair. Claude Code's bash sandbox uses bubblewrap for the
  sandbox itself and socat to forward the ssh-agent socket through the
  sandbox; installing one without the other leaves a broken posture
  where signing fails or the sandbox refuses to start.
- The installer MUST skip both `bubblewrap` and `socat` inside
  devcontainers and Codespaces. The container is the trust boundary
  there and `sandbox.enabled: false` in `settings.container.json`.
- On Ubuntu, if the apt-resolvable `git` is < 2.35, the installer
  MUST opportunistically install git >= 2.35 from the official PPA
  (`_ensure_modern_git_apt`). Rationale: signing requires the
  `user.signingkey = key::<literal>` parser that landed in git 2.35.
  Debian bookworm and later already ship qualifying git.

### Distribution channels

- On macOS, every install MUST go through Homebrew. No raw GitHub-release
  downloads on macOS.
- On Linux, the installer MUST prefer GitHub releases with SHA-256
  verification for tools where releases are available and authoritative
  (e.g., starship, zoxide, eza, sd, scc, yq, watchexec, ast-grep,
  difftastic).
- For tools well-served by distro packages on Linux (e.g., `jq`, `fzf`),
  the installer MAY use `apt`/`apk` directly.
- On Alpine, the installer MUST prefer musl-static binaries when GitHub
  releases distribute them.

### Verification and integrity

- For every GitHub-release download, the installer MUST verify the SHA-256
  checksum against the published `checksums.txt` (or equivalent) before
  extraction.
- A failed checksum MUST abort the install of that tool and MUST NOT leave
  partial artifacts on disk.
- The installer MUST NOT trust a download without verification, even on
  re-runs.

### Idempotency

- Re-installing an already-installed tool of the correct version MUST be a
  no-op (exit 0, no log noise beyond "already installed").
- Re-running `install_packages` MUST NOT re-download already-verified
  binaries; the cache key is "binary at expected path with expected
  version".

### AI-tool gating

- Claude Code, Codex CLI, ast-grep, and difftastic MUST be skipped entirely
  when `DOTFILES_NO_AI_TOOLS=1` is set.
- atuin and bash-preexec MUST be skipped entirely when `DOTFILES_NO_ATUIN=1`
  is set.

## Scenarios

### Scenario: Fresh Ubuntu install pulls starship from GitHub

GIVEN a fresh Ubuntu 24.04 host
AND no starship binary on PATH
WHEN `install_packages` runs
THEN the installer downloads
`https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz`
AND verifies its SHA-256 against the published checksums file
AND extracts `starship` to `~/.local/bin/starship`
AND logs `starship installed: version X.Y.Z`.

### Scenario: macOS install routes everything through brew

GIVEN a macOS host with Homebrew installed
WHEN `install_packages` runs
THEN the installer issues `brew install fzf ripgrep fd bat ...` (one command, all tools)
AND issues NO `curl ... github.com/.../releases` calls.

### Scenario: Checksum mismatch aborts cleanly

GIVEN a Linux install of `yq` from GitHub releases
AND the downloaded tarball's SHA-256 does not match the published checksum
WHEN the installer attempts verification
THEN it logs `Checksum mismatch for yq, skipping install`
AND removes the partial download
AND continues installing other tools (does NOT abort the entire run).

### Scenario: AI tool skip honored

GIVEN `DOTFILES_NO_AI_TOOLS=1` is exported
WHEN `install_packages` runs
THEN no `claude` or `codex` binary is installed
AND `ast-grep` and `difftastic` are also skipped
AND the installer logs `DOTFILES_NO_AI_TOOLS=1, skipping AI tool installation`.

## Non-Behavior

- The installer does NOT install project-dependent tools (gh, docker,
  kubectl, mise, uv) -- these belong to projects' devcontainer.json.
- The installer does NOT install language runtimes (node, python, rust, go).
- The installer does NOT pin tool versions to specific releases (uses
  "latest" via the GitHub API). Reproducibility is sacrificed for the
  ability to pull bug fixes without manual updates.
- The installer does NOT install from snap, flatpak, or distroless image
  registries.
- The installer does NOT use sudo on macOS (Homebrew handles privilege).
