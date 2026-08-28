# diagnostics

## Overview

User-facing diagnostic surface.
The `dotfiles-doctor` shell function reports installation health (symlinks, tools, git config, signing key state).
Shell profiling (`ZSH_PROFILE=1`) surfaces zsh startup bottlenecks.
Install-time logging is colored and structured.
Together they form the "is this broken?" loop -- a user can self-diagnose without reading code.

## Requirements

### dotfiles-doctor

- `dotfiles-doctor` MUST be defined in `shell/functions.sh` and available in any interactive shell after install.
- `dotfiles-doctor` MUST check, in distinct sections:
  - **Symlinks**: every expected symlink exists and points where expected.
  - **Core Tools**: every core tool resolves on PATH and reports a sensible version.
  - **Git Configuration**: `user.name`, `user.email`, signing key, `[include]` for dotfiles config.
  - **Summary**: count of passed / warnings / failed.
- Each check MUST output a colored `ok`, `warn`, or `fail` prefix.
- The function MUST exit 0 when all critical checks pass (warnings allowed); non-zero only on failures.
- The function MUST NOT have side effects (read-only).

### Shell profiling

- Setting `ZSH_PROFILE=1` MUST cause `~/.zshrc` to load `zprof` early and emit a `zprof` report at shell exit.
- The report MUST show per-function CPU time and call count, sorted by cumulative time descending.
- CI builds MUST log per-component shell startup timing automatically (without requiring `ZSH_PROFILE=1`).

### Install-time logging

- `bootstrap/logging.sh` MUST define `log_section`, `log_info`, `log_success`, `log_warn`, `log_error` functions.
- `tests/validate-dotfiles.sh` MUST source `bootstrap/detect.sh` and `bootstrap/logging.sh` rather than redefining environment-detection and logging helpers locally.
  Local redefinitions drift; the standalone copy previously missed `/.dockerenv` detection, masking devcontainer state.
- Each function MUST emit color-coded output to stderr (or stdout where appropriate).
- `log_section` MUST emit a visually distinct header for each major install phase (Environment Detection, Installing Packages, Creating Symlinks, etc.).
- The logging functions MUST work without color when stdout is not a TTY (CI logs).

### Failure messaging

- When `install.sh` fails, the error message MUST include actionable next steps (e.g., the apt-get command to manually install missing base packages).
- When SSH signing setup fails to find a key, the message MUST tell the user how to add a key and re-run.

## Scenarios

### Scenario: Doctor reports green after fresh install

GIVEN a successful `./install.sh` just completed
WHEN the user runs `dotfiles-doctor`
THEN every symlink reports `ok`
AND every core tool reports `ok` with a version string
AND git identity reports `ok`
AND the summary line reads `27 passed, 0 warnings, 0 failed`
AND the function exits 0.

### Scenario: Doctor catches missing tool

GIVEN a host where `bat` is not installed
WHEN the user runs `dotfiles-doctor`
THEN the Core Tools section reports `fail  bat (not found)`
AND the summary increments the failed count
AND the function exits non-zero.

### Scenario: ZSH_PROFILE shows zoxide as deferred

GIVEN a user runs `ZSH_PROFILE=1 zsh -i -c exit`
WHEN the shell exits
THEN `zprof` reports
AND zoxide-related functions appear in `precmd` time, not in `.zshrc` time
AND total interactive startup time is under 200ms on a warm cache.

### Scenario: Install log readable in CI

GIVEN `./install.sh` runs in GitHub Actions (non-TTY)
WHEN logging functions emit output
THEN section headers appear without ANSI escape sequences
AND log_warn / log_error are recognizable in plain text
AND the CI log is grep-friendly.

## Non-Behavior

- `dotfiles-doctor` does NOT modify any state or attempt to fix issues -- it only reports.
- `dotfiles-doctor` does NOT contact any network endpoint (no telemetry, no version-check ping).
- The shell profiling does NOT run by default (opt-in via env var).
- Install-time logging does NOT log secrets or tokens, even on debug paths.
- Diagnostics do NOT enumerate every installed tool -- only the core set the doctor checks.
  Project-dependent tools are out of scope.
