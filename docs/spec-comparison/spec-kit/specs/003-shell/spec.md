# Feature Specification: Shell Configuration

**Branch**: `003-shell` | **Date**: 2026-04-01 | **Status**: Implemented

## User Scenarios & Testing

### User Story 1 - Fast interactive zsh startup (Priority: P1)

A developer opening a terminal wants the prompt to appear in under 200ms, even with completions and zoxide and direnv all wired up.

**Independent Test**: `time zsh -i -c exit` on a warm cache -> < 0.2s.

**Acceptance Scenarios**:
```
GIVEN ~/.cache/zsh/zcompdump-*.zwc exists from earlier today
WHEN the user starts a new interactive zsh
THEN compinit reads the cached dump (no fpath rescan)
  AND zoxide and direnv defer to first prompt
  AND the prompt is interactive in <200ms
```

### User Story 2 - 80+ aliases without shadowing standard tools (Priority: P1)

A developer wants ergonomic aliases for git/docker/k8s without losing muscle memory for `grep` / `find`.

**Independent Test**: After install, assert >= 80 aliases defined and `grep` resolves to system grep (not rg) by default.

**Acceptance Scenarios**:
```
GIVEN ./install.sh ran without DOTFILES_OPINIONATED_ALIASES set
WHEN the user runs `alias | wc -l`
THEN at least 80 aliases are listed
  AND `type grep` returns the system binary, not an alias
  AND `gs`, `gl`, `gd`, `k`, `d`, `dc` are aliased
```

### User Story 3 - Local override layered on top (Priority: P2)

A developer wants a per-machine alias without forking the dotfiles.

**Independent Test**: Add `alias x='echo hi'` to `~/.aliases.local`, restart shell, run `x` -> "hi".

**Acceptance Scenarios**:
```
GIVEN ~/.aliases.local defines `alias x='echo hi'`
WHEN ~/.bashrc is sourced
THEN ~/.aliases.local loads after aliases.sh
  AND `type x` returns alias x='echo hi'
```

### Edge Cases

- **No yazi installed**: alias `y` is still defined; first invocation produces "command not found".
  Acceptable.
- **`ZSH_PROFILE=1`**: `zprof` output appears at exit; startup time baseline shifts by ~50ms (acceptable).
- **macOS bash 3.2 in `bash -c`**: aliases.sh and exports.sh must not use bash 4 features.

## Requirements

### Functional Requirements

- **FR-001** Installer MUST symlink `~/.bashrc`, `~/.bash_profile`, `~/.zshrc`, `~/.zprofile`.
- **FR-002** `aliases.sh` MUST define >= 80 aliases.
- **FR-003** `grep` and `find` MUST NOT be aliased by default.
- **FR-004** `DOTFILES_OPINIONATED_ALIASES=1` MUST shadow `grep` -> `rg` and `find` -> `fd`.
- **FR-005** `functions.sh` MUST define >= 25 functions including `mkcd`, `extract`, `dotfiles-doctor`.
- **FR-006** `exports.sh` MUST set XDG vars, EDITOR chain, FZF defaults, CLAUDE_CONFIG_DIR.
- **FR-007** Shell rc files MUST source any of `~/.{bashrc,zshrc,exports, aliases,functions}.local` if present.
- **FR-008** zsh `compinit` MUST cache for 24 hours.
- **FR-009** zoxide and direnv MUST initialize on first prompt (deferred), not during startup.
- **FR-010** `ZSH_PROFILE=1` MUST emit a `zprof` report at shell exit.

### Key Entities

- **Override file**: `~/.<shell-component>.local` -- gitignored, sourced conditionally.

## Success Criteria

- **SC-001** `time zsh -i -c exit` < 200ms on warm cache (CI assertion).
- **SC-002** `time zsh -i -c exit` < 500ms on cold cache.
- **SC-003** Bash startup < 100ms on every matrix cell.
- **SC-004** No alias shadows a standard Unix command unless `DOTFILES_OPINIONATED_ALIASES=1`.

## Assumptions

- The user's terminal supports 256 colors (for the bat / fzf themes).
- The user's $HOME is writable (override files live there).
- POSIX shell utilities are present.
