# Implementation Plan: Shell Configuration

**Branch**: `003-shell` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)

## Summary

Bash and zsh runtime config split into modular files (aliases, functions,
exports, completion). zsh startup optimized via cached compinit and
deferred init for zoxide/direnv. Local-override convention via gitignored
`*.local` files for per-machine customization.

## Technical Context

| Field             | Value                                                                          |
|-------------------|--------------------------------------------------------------------------------|
| Language/Version  | Bash 3.2+ (POSIX); zsh 5.x+                                                    |
| Dependencies      | fzf, zoxide, atuin, direnv, carapace (for completions / functions)             |
| Storage           | `~/.{bashrc,zshrc,bash_profile,zprofile}` symlinks; `~/.cache/zsh/` for compinit |
| Testing           | `tests/test-functions.sh`, shell startup time captured in CI                   |
| Target Platform   | macOS, Ubuntu, Debian, Alpine                                                  |
| Project Type      | Single Project                                                                 |
| Performance Goals | zsh startup <200ms warm, <500ms cold                                           |
| Constraints       | macOS bash 3.2 (no associative arrays); POSIX where possible                   |
| Scale/Scope       | 80+ aliases, 25+ functions, 5 override files                                   |

## Constitution Check

| Article                            | Status | Notes                                                                       |
|------------------------------------|--------|------------------------------------------------------------------------------|
| I. Developer-Specific              | PASS   | Universal shell QoL; project-specific aliases live in `~/.aliases.local`.    |
| II. Defense-in-Depth Security      | PASS   | No credentials in shell config; override files are gitignored.               |
| III. Cross-Platform Parity         | PASS   | Bash 3.2 floor respected; both bash and zsh tested.                          |
| IV. Idempotent and Reversible      | PASS   | Symlinks; backup on replacement.                                             |
| V. Opt-In for High-Risk Surface    | PASS   | `DOTFILES_OPINIONATED_ALIASES` defaults off (would shadow grep/find).       |

## Project Structure

```
shell/
|-- .bashrc, .bash_profile, .zshrc, .zprofile
|-- aliases.sh, functions.sh, exports.sh, completion.sh
```

### Structure Decision

Single Project. Shell config is a flat set of sourced files with no
nesting. The rc files orchestrate; aliases / functions / exports /
completion each live in their own concern-specific file.

## Complexity Tracking

(empty)
