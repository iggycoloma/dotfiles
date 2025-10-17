# Continuous Integration (CI) Setup

This document describes the CI system for testing the dotfiles across multiple platforms and configurations.

## Overview

The CI pipeline automatically tests the dotfiles installation on every push and pull request, ensuring compatibility across different operating systems, shells, and environments.

## Platforms Tested

### Linux Containers (via Docker)

**Ubuntu** (WSL2 proxy):
- Ubuntu 20.04 (bash)
- Ubuntu 22.04 (bash + zsh)
- Ubuntu 24.04 (bash + zsh)

**Debian**:
- Debian 11 Bullseye (bash)
- Debian 12 Bookworm (bash + zsh)

**Alpine**:
- Alpine latest (bash)
- Tests musl libc compatibility
- Tests apk package manager

### macOS (Native Runners)

- macOS 13 Ventura (bash + zsh)
- macOS 14 Sonoma (bash + zsh)

**Note**: macOS uses native GitHub Actions runners, not Docker containers, as Docker doesn't support macOS containers on Linux hosts.

## What Gets Tested

Each platform test includes:

1. **Installation**
   - Run `install.sh` on a clean system
   - Verify all bootstrap scripts execute successfully
   - Test environment detection (container vs host)

2. **Shell Startup**
   - Test bash interactive shell startup
   - Test zsh interactive shell startup (when available)
   - Verify no errors or hangs (5-second timeout)

3. **Core Tools Verification**
   - fzf (fuzzy finder)
   - ripgrep (rg)
   - fd (file finder)
   - bat (cat replacement)
   - jq (JSON processor)
   - eza (ls replacement)
   - zoxide (smart cd)
   - starship (prompt)
   - delta (git diff)

4. **Symlinks**
   - Verify symlinks created correctly
   - Test symlink targets point to dotfiles repo

5. **Aliases and Functions**
   - Test key aliases available (ll, etc.)
   - Test key functions available (mkcd, etc.)

6. **Git Configuration**
   - Verify git config loaded
   - Test git aliases configured

7. **Idempotency**
   - Run installation twice
   - Verify second run succeeds without errors

## Test Matrix

| Platform | Shell | Container | Notes |
|----------|-------|-----------|-------|
| Ubuntu 20.04 | bash | Yes | LTS, older packages |
| Ubuntu 22.04 | bash | Yes | LTS, current stable |
| Ubuntu 22.04 | zsh | Yes | Tests zsh + zinit |
| Ubuntu 24.04 | bash | Yes | Latest, newer packages |
| Ubuntu 24.04 | zsh | Yes | Latest + zsh |
| Debian 11 | bash | Yes | Stable release |
| Debian 12 | bash | Yes | Current stable |
| Debian 12 | zsh | Yes | Current stable + zsh |
| Alpine | bash | Yes | musl libc, apk |
| macOS 13 | bash | No | Native runner |
| macOS 13 | zsh | No | Native runner |
| macOS 14 | bash | No | Native runner, Apple Silicon |
| macOS 14 | zsh | No | Native runner, Apple Silicon |

## Workflow Structure

### Jobs

1. **test-linux-containers**: Tests all Linux distributions using Docker containers
   - Matrix build with 9 configurations
   - Runs in parallel for speed
   - Uses ubuntu-latest runner with container images

2. **test-macos**: Tests macOS using native runners
   - Matrix build with 4 configurations
   - Runs in parallel
   - Uses actual macOS VMs (macos-13, macos-14)

3. **test-summary**: Aggregates results
   - Runs after all tests complete
   - Reports overall success/failure
   - Provides summary for pull requests

### Workflow Triggers

- **Push**: On main, master, and feature branches
- **Pull Request**: Targeting main or master
- **Manual**: Via workflow_dispatch

## Running Tests Locally

### Prerequisites

- Docker installed
- Bash shell

### Test on Ubuntu

```bash
docker run --rm -it ubuntu:22.04 bash -c "
  apt-get update && apt-get install -y git curl sudo
  git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/.dotfiles
  cd ~/.dotfiles
  bash install.sh
  bash tests/test-install.sh
"
```

### Test on Debian

```bash
docker run --rm -it debian:bookworm bash -c "
  apt-get update && apt-get install -y git curl sudo
  git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/.dotfiles
  cd ~/.dotfiles
  bash install.sh
  bash tests/test-install.sh
"
```

### Test on Alpine

```bash
docker run --rm -it alpine:latest sh -c "
  apk add --no-cache git curl bash sudo
  git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/.dotfiles
  cd ~/.dotfiles
  bash install.sh
  bash tests/test-install.sh
"
```

### Test on macOS

```bash
cd ~/.dotfiles
bash install.sh
bash tests/test-install.sh
```

## CI Environment Variables

The CI workflow sets:
- `CI=true`: Indicates running in CI environment
- Used by install script for non-interactive mode
- Used by test script to skip host-only tools

## Troubleshooting

### Tests Failing on Alpine

Alpine uses musl libc and apk package manager, which can have different behaviors:
- Some tools may not be available via apk
- GitHub releases are used as fallback
- Binary compatibility may differ

### Tests Failing on macOS

macOS-specific issues:
- Homebrew may need to be installed first
- Some tools may have different names (e.g., gnu-sed vs sed)
- /proc filesystem doesn't exist on macOS

### Container Detection

The test suite uses multiple methods to detect container environments:
- `/.dockerenv` file (Docker)
- `$CODESPACES` environment variable
- `$REMOTE_CONTAINERS` environment variable
- `$CI` environment variable
- `/proc/1/environ` contents (Linux only)

### Shell Startup Timeouts

If shells hang on startup:
- Check for interactive prompts in rc files
- Verify no network-dependent operations in startup
- Test locally with `bash -i -c 'echo OK'`

## Adding New Tests

To add new test cases:

1. Edit `tests/test-install.sh`
2. Add test functions using existing helpers:
   - `test_exists`: Check file/directory exists
   - `test_command`: Verify command available
   - `test_symlink`: Verify symlink correct
3. Add to appropriate log_section
4. Test locally before committing

## Adding New Platforms

To add a new platform to CI:

1. Edit `.github/workflows/ci.yml`
2. Add to the matrix under `test-linux-containers` (for Docker) or `test-macos` (for native runners)
3. Specify:
   - `os`: Docker image or runner
   - `shell`: bash or zsh
   - `platform`: Descriptive name
4. Test the workflow on a branch first

## Performance

Typical CI run times:
- Linux containers: ~3-5 minutes per configuration
- macOS runners: ~5-10 minutes per configuration
- Total parallel time: ~10-15 minutes
- All platforms tested in parallel for efficiency

## CI Badge

Add to README.md:

```markdown
[![CI](https://github.com/YOUR_USERNAME/dotfiles/workflows/CI/badge.svg)](https://github.com/YOUR_USERNAME/dotfiles/actions)
```

## Future Improvements

Potential enhancements:
- Test with different versions of tools (older fzf, etc.)
- Test partial installations (missing dependencies)
- Test upgrade scenarios (existing old install → new)
- Add performance benchmarks (shell startup time)
- Test on FreeBSD (native POSIX, closer to macOS than Linux)
- Cache tool downloads to speed up runs
- Add failure notifications (Slack, email, etc.)
