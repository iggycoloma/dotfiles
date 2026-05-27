# Feature Specification: Diagnostics

**Branch**: `012-diagnostics` | **Date**: 2026-04-01 | **Status**: Implemented

## User Scenarios & Testing

### User Story 1 - Doctor reports installation health (Priority: P1)

A developer suspects something's wrong with their dotfiles install.
They run one command and get a clear, actionable report.

**Acceptance Scenarios**:
```
GIVEN a successful ./install.sh just completed
WHEN the user runs `dotfiles-doctor`
THEN every symlink reports `ok`
  AND every core tool reports `ok` with a version string
  AND git identity reports `ok`
  AND the summary line reads "27 passed, 0 warnings, 0 failed"
  AND the function exits 0
```

```
GIVEN bat is not installed (manual removal)
WHEN dotfiles-doctor runs
THEN Core Tools section reports "fail  bat (not found)"
  AND summary increments failed count
  AND the function exits non-zero
```

### User Story 2 - Shell startup profiling (Priority: P2)

A developer notices zsh feels slow and wants to find the bottleneck.

**Acceptance Scenarios**:
```
GIVEN ZSH_PROFILE=1 is set in the user's environment
WHEN they run `zsh -i -c exit`
THEN zprof emits per-function timing at exit
  AND zoxide / direnv functions appear under precmd time (deferred)
  AND not under .zshrc startup time
  AND total interactive startup is < 200ms on a warm cache
```

### User Story 3 - Install logging readable in CI (Priority: P2)

A developer reading CI logs can grep / scan install output without
ANSI escape noise.

**Acceptance Scenarios**:
```
GIVEN ./install.sh runs in GitHub Actions (non-TTY)
WHEN logging functions emit output
THEN section headers contain no ANSI escape sequences
  AND log_warn / log_error are recognizable as plain text
  AND the log is grep-friendly
```

### Edge Cases

- **Doctor in a pristine container before install**: reports
  expected failures (no symlinks, no tools); exits non-zero. This
  is by design (it's a diagnostic, not an installer).
- **`ZSH_PROFILE=1` in non-zsh shells**: ignored (env var has no
  effect outside zsh).
- **Logging when stdout is not a TTY but stderr is**: each function
  picks its destination per the spec; CI logs both.

## Requirements

### Functional Requirements

- **FR-001** `dotfiles-doctor` MUST be defined in `shell/functions.sh`
  and available in any interactive shell.
- **FR-002** `dotfiles-doctor` MUST check Symlinks, Core Tools, Git
  Configuration sections.
- **FR-003** Each check MUST output a colored `ok`, `warn`, or `fail`
  prefix (or plain text when not in a TTY).
- **FR-004** Function MUST exit 0 when all critical checks pass
  (warnings allowed); non-zero only on failures.
- **FR-005** Function MUST be read-only (no side effects).
- **FR-006** `ZSH_PROFILE=1` MUST cause `~/.zshrc` to load `zprof`
  early and emit a report at shell exit.
- **FR-007** Report MUST show per-function CPU time and call count,
  sorted by cumulative time descending.
- **FR-008** CI builds MUST log per-component shell startup timing
  automatically.
- **FR-009** `bootstrap/logging.sh` MUST define `log_section`,
  `log_info`, `log_success`, `log_warn`, `log_error`.
- **FR-010** Each logging function MUST emit color-coded output in a
  TTY and plain output otherwise.
- **FR-011** Install failure messages MUST include actionable next
  steps.
- **FR-012** SSH-signing failure message MUST tell the user how to
  add a key and re-run.
- **FR-013** `tests/validate-dotfiles.sh` MUST source
  `bootstrap/detect.sh` and `bootstrap/logging.sh` rather than
  redefining detection or logging helpers locally. Rationale: the
  prior local copies drifted from the shared library and missed
  `/.dockerenv` detection, causing devcontainer-only doctor checks
  to silently skip. The diagnostic and the installer MUST agree on
  what counts as a devcontainer.

### Key Entities

- **Check**: a single test in dotfiles-doctor with a name, a
  predicate, and a status (ok / warn / fail).

## Success Criteria

- **SC-001** dotfiles-doctor reports 0 failures after install on
  every CI matrix cell.
- **SC-002** ZSH_PROFILE=1 surfaces the actual slowest function in
  test-suite verification.
- **SC-003** CI logs can be grepped for `log_section` / `log_warn` /
  `log_error` without ANSI noise.

## Assumptions

- `bat`, `delta`, and other "ok if present" tools may legitimately
  be missing on minimal hosts; doctor reports `warn` not `fail`
  for these.
- The user's terminal supports ANSI when interactive (we don't
  detect terminfo).
- `tput colors` returns sensibly (or we degrade to plain text).
