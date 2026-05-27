# Dotfiles Constitution

**Version**: 1.1.0 **Ratification Date**: 2026-04-01 **Last Amended Date**: 2026-05-27

The principles in this constitution are non-negotiable.
The Constitution Check section in every `plan.md` validates the proposed implementation against these articles.
Violations require explicit justification in the plan's Complexity Tracking table; un-justified violations block task generation.

## Core Principles

### Article I: Developer-Specific, Not Project-Specific

This repository installs (a) universally useful CLI tools and (b) agentic coding tools (Claude Code, Codex CLI).
It does NOT install (c) project-dependent tools (gh, docker, kubectl, mise, uv, language runtimes).

**Rules**:
- New tools are added only if they improve every terminal session regardless of project context.
- Project-dependent tools may have aliases, completions, and state-persistence surface in this repo, but no installation logic.
- An alias for a missing tool is harmless ("command not found" is fine); an installer that drags in tools the user did not ask for is not.

**Rationale**: Without this boundary the repo becomes a junk drawer of every tool the author ever used on a project, bloating install time and confusing new users about what is essential.

### Article II: Three-Tier Defense

Each risk is defended at exactly one tier; tiers do not duplicate each other's coverage.
Weakening any tier requires constitutional amendment.

**Tiers**:

1. **Tier 1 -- file content**.
   `Read/Write/Edit` deny globs in `claude-code/settings.json` and `claude-code/settings.container.json`, plus the substring scan in `pre-security.sh`.
   This is the only layer that defends credential exposure.
2. **Tier 2 -- system state and network**.
   The OS-level Claude Code sandbox (bwrap on Linux/WSL2, seatbelt on macOS) on hosts; the container boundary inside devcontainers; the `Bash(sudo:*)` deny as the upstream gate.
   The Bash deny list MUST NOT enumerate sudo-gated commands -- they cannot do anything meaningful without sudo, and sudo is already blocked.
3. **Tier 3 -- remote and shared**.
   GitHub branch protection on the server.
   The Bash deny list MUST NOT attempt to simulate trunk protection with `git push * main*` glob-prefix tripwires; the prefix matcher does not support inline wildcards reliably and the server is the only authoritative defense.

**Rules**:
- New deny rules prefer `Read/Write/Edit` with a glob when the risk is file content; `Bash(prefix:*)` only as a tripwire for local-state footguns where no other tier catches a typo.
- Hooks must remain working on macOS bash 3.2.
- No bypassing hooks with `--no-verify` or `git -c core.hooksPath=/dev/null`.
- No MCP servers installed by default (they bypass settings deny rules).
- `git push --force-with-lease` is allowed; plain `git push --force` and `git push -f` are denied (the lease checks for upstream movement, which is the actual safety property locally).

### Article III: Cross-Platform Parity

The 13+ platform CI matrix (Ubuntu 20.04/22.04/24.04, Debian 11/12, Alpine latest, macOS 15/26, Codespaces; bash and zsh per applicable platform) is the authoritative compatibility surface.

**Rules**:
- No feature ships if it does not pass on every matrix cell.
  No platform-specific carve-outs ("works on Linux only" is rejected unless the feature is inherently Linux-specific, e.g. apt commands -- and even then it must no-op cleanly on macOS).
- macOS bash 3.2 is the floor.
  No associative arrays, no `${var,,}` modifiers, careful regex.
- POSIX-shell-compatible where possible; bash-specific features called out.

**Rationale**: Developers move between machines.
A dotfiles install that works on the author's MacBook but breaks in a teammate's Codespace defeats the purpose.

### Article IV: Idempotent and Reversible Installs

`./install.sh` is safe to re-run any number of times.

**Rules**:
- Existing files are backed up to `~/.dotfiles_backup_<timestamp>/` before being replaced.
- Re-running the installer produces no error, no duplicate config, and no broken state.
- Installation toggles (DOTFILES_NO_AI_TOOLS=1, DOTFILES_NO_ATUIN=1, etc.) are honored on every run, not just the first.
- `dotfiles-doctor` reports green after any successful install.

### Article V: Opt-In for High-Risk Surface

Capabilities with non-trivial security, performance, or behavior implications are opt-in, not default-on.

**Currently opt-in**:
- Unattended harness (`unattended/`): `--with-unattended` or `DOTFILES_INSTALL_UNATTENDED=1`.
  Vocabulary note: "agentic" describes the interactive AI tools (Claude Code, Codex CLI) that always install.
  The unattended harness is the autonomous-loop stack (ralph, dc-audit rubric, hardened devcontainer profile) that opts in.
  The capability was renamed from "agentic harness" in PR #53 to make this distinction explicit.
- Opinionated aliases (shadowing `grep`, `find`): `DOTFILES_OPINIONATED_ALIASES=1`.
- MCP servers: explicit user request.
- Workspace-local state persistence: rejected entirely (security analysis in `docs/future-workspace-local-state.md`).

**Rule**: New capabilities default to off when they (a) execute autonomously, (b) shadow standard Unix commands, (c) widen the credential or filesystem attack surface, or (d) change well-established behavior in ways users may not expect.

## Technology Requirements

- **Shell**: bash (POSIX compatible), zsh 5.x+ for shell config. macOS bash 3.2 is the compatibility floor.
- **Lint**: shellcheck on every `*.sh` file.
  No `# shellcheck disable=` without a comment explaining why.
- **Tests**: hand-rolled bash test scripts under `tests/`.
  New capabilities add tests to the appropriate suite (unit / packages / integration / security / functions).
- **Distribution**: GitHub releases with SHA-256 verification on Linux (musl-static where available); Homebrew on macOS; native package managers (apt, apk) as fallback only.
- **Config formats**: TOML for tool config (starship), JSON for AI tool settings, YAML for CI and the dc-audit rubric, plain shell elsewhere.

## Development Practices

- **Conventional commits** with the format `type(scope): description`, minimum 10-character subject.
  Allowed types: feat, fix, refactor, docs, test, chore, ci, build, perf, style.
  Enforced by `commit-msg` hook.
- **No AI attribution** in commits.
  No `Co-Authored-By: Claude`, no "Generated by Claude Code" trailers.
  Enforced by `commit-msg` hook.
- **No decorative emoji** in code, docs, or commits.
  Enforced by `pre-code-no-emoji.sh` (file content) and the `commit-msg` hook (commit messages).
  The Claude plan and memory paths are exempt from `pre-code-no-emoji.sh` because the harness writes Unicode symbols into those locations.
- **Host vs container settings variants** stay in lockstep (allow/deny lists, hook registrations) except for the sandbox block.
  The `bin/settings-drift.sh` lint (a `make lint` prerequisite) blocks asymmetric edits and missing-variant drift.
- **Feature branches and PRs only.** No direct pushes to `main`.
- **No backwards-compat shims** when removing code.
  Clean removal; git history is the audit trail.
- **PR-driven changes** with shellcheck + full `make test` matrix passing before merge.

## Governance

- This constitution is the contract that every `plan.md` validates against via the Constitution Check section.
- Amendments follow semantic versioning:
  - **MAJOR**: removing or fundamentally changing an article (e.g., dropping cross-platform parity).
  - **MINOR**: adding an article or expanding scope of an existing one.
  - **PATCH**: clarifying language without changing meaning.
- Amendments require: (1) a PR titled `docs(constitution): ...`, (2) updating `Last Amended Date` to ISO 8601, (3) bumping the version per the rules above, (4) updating any plan or spec that newly violates or newly satisfies the amended article.
- The Sync Impact Report at the top of the amendment PR description must list every artifact (template, plan, spec) that was touched as a downstream effect.
