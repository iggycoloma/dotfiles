# Feature Specification: Packages

**Branch**: `002-packages` | **Date**: 2026-04-01 | **Status**: Implemented

## User Scenarios & Testing

### User Story 1 - Linux: pull latest from GitHub releases (Priority: P1)

A developer on Ubuntu/Debian/Alpine wants modern CLI tools at recent versions, not the years-stale versions in distro packages.

**Why this priority**: Distro packages are the bottleneck on Linux; this unlocks the value of every other capability.

**Independent Test**: Run `install_packages` on a fresh Ubuntu 22.04 container, assert `starship --version` returns >= 1.0.0 and the binary came from GitHub releases (check via `which`).

**Acceptance Scenarios**:

```
GIVEN a fresh Ubuntu 22.04 container with no starship installed
WHEN install_packages runs
THEN starship is downloaded from github.com/starship/starship/releases
  AND its SHA-256 checksum is verified before extraction
  AND starship --version returns a recent version
  AND the binary lives in ~/.local/bin/starship
```

### User Story 2 - macOS: Homebrew for everything (Priority: P1)

A developer on macOS wants the same set of tools without bypassing Homebrew.

**Why this priority**: macOS users expect Homebrew; raw release downloads break Apple Silicon compatibility detection and SIP boundaries.

**Independent Test**: Run `install_packages` on a macOS host with Homebrew present; assert no `curl ... github.com/.../releases` calls were made.

**Acceptance Scenarios**:

```
GIVEN a macOS host with brew installed
WHEN install_packages runs
THEN every tool install issues `brew install <tool>`
  AND zero direct GitHub release downloads occur
```

### User Story 3 - AI tools opt-out (Priority: P2)

A developer who manages their own AI tooling wants to skip Claude Code/Codex/ast-grep/difftastic installation.

**Why this priority**: P2 -- only matters for power users who want to manage AI tools out-of-band; most users want default-on.

**Independent Test**: Run with `DOTFILES_NO_AI_TOOLS=1`; assert no `claude` or `codex` binary is on PATH after install.

**Acceptance Scenarios**:

```
GIVEN DOTFILES_NO_AI_TOOLS=1 is exported
WHEN install_packages runs
THEN no claude/codex/ast-grep/difftastic binary is installed
  AND the installer logs the skip explicitly
```

### Edge Cases

- **Checksum mismatch**: Skip the affected tool, log loudly, continue installing others.
  Do not abort the entire run.
- **GitHub API rate limit**: Tool detection falls back to "already installed" check via `command -v`; install is skipped if version is acceptable.
- **Alpine without musl-static binary**: Fall back to `apk` package if available; skip if not.

## Requirements

### Functional Requirements

- **FR-001** Core tools MUST install on every supported environment.
- **FR-002** Linux installs MUST prefer GitHub releases for tools where releases are authoritative.
- **FR-003** macOS installs MUST go through Homebrew exclusively.
- **FR-004** Every GitHub-release download MUST be SHA-256 verified before extraction.
- **FR-005** Failed checksums MUST abort that tool's install (not the whole run).
- **FR-006** Re-installing an already-current tool MUST be a no-op.
- **FR-007** AI tool installation MUST be skipped under `DOTFILES_NO_AI_TOOLS=1`.
- **FR-008** atuin installation MUST be skipped under `DOTFILES_NO_ATUIN=1`.
- **FR-009** On Linux hosts (apt/apk), `bubblewrap` and `socat` MUST be installed as a paired prerequisite for the Claude Code host sandbox: `bwrap` unshares the network namespace, `socat` bridges it to the egress proxy.
  Inside devcontainers both packages MUST be skipped -- the container boundary is the sandbox there, and bwrap inside containers has known seccomp/userns incompatibilities.
  Installing one without the other is a bug; treat them as one unit.
- **FR-010** On Ubuntu / Pop!_OS, if the apt-resolvable `git` is older than 2.35, `_ensure_modern_git_apt` MUST opportunistically add the official `ppa:git-core/ppa` repository and upgrade.
  Rationale: SSH commit signing requires the `key::<literal>` parser shipped in git 2.35 (Ubuntu 22.04 jammy stock is 2.34.1, where the value is passed straight to ssh-keygen as a file path and signing fails).
  Debian bookworm and later already ship git >= 2.35, so the gate is Ubuntu-only and a no-op when the stock package already qualifies.
  PPA-add failures MUST warn and continue (signing simply stays disabled).

### Key Entities

- **Tool tier**: `core | agentic | optional | preferences-only`.
  Drives install gating per environment.
- **Distribution channel**: `brew | github-release | apt | apk | ppa`.
- **Paired prerequisite**: `bubblewrap` + `socat` -- two packages that together form one capability (the host sandbox); never installed alone.

## Success Criteria

- **SC-001** Cold install of all core + agentic tools completes in under 2 minutes on a Codespace (network-bound).
- **SC-002** Re-install (everything already current) completes in under 10 seconds.
- **SC-003** Every Linux GitHub-release download has a verified checksum in CI logs.
- **SC-004** Zero `apt-get install` calls for tools that have a GitHub-release on Linux (ripgrep, starship, zoxide, etc.).

## Assumptions

- Network access is available on first install for tool downloads.
- The GitHub API is reachable (no per-IP rate limits hit).
- Homebrew is already installed on macOS (we do not bootstrap brew).
- The user accepts "latest" for tool versions; no version pinning.
