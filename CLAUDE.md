# Dotfiles -- Project-Specific Claude Code Instructions

See `AGENTS.md` for shared guardrails, CLI tool preferences, and security model.
This file covers Claude-specific context for working in this repository.

## Design Philosophy

This repo is developer-specific, not project-specific. It installs universally useful
CLI tools and agentic coding tools (Claude Code, Codex CLI). For project-dependent tools
(gh, docker, kubectl, etc.), it supplies configuration surface (aliases, completions,
state persistence) without installing them. Projects own their own tooling; this repo
ensures the developer's preferences are ready.

When making changes, respect this boundary: don't add installation logic for tools that
belong to individual projects. Do add configuration, completions, and state persistence
for tools developers commonly encounter.

## Quality Gates

- `make lint` -- shellcheck all `.sh` files (CI blocks merge on failure)
- `make test` -- run full test suite (unit + packages + integration)
- `make test-unit` / `make test-packages` / `make test-integration` -- run individually

## Repository Architecture

This repo deploys a portable CLI environment. Key directories:

| Directory | Purpose |
|-----------|---------|
| `bootstrap/` | Environment detection, package installation, symlink management |
| `shell/` | Bash/zsh configs, aliases, functions, exports, completions |
| `git/` | Git config, global hooks (conventional commits, gitleaks) |
| `claude-code/` | Global Claude Code config (deployed to `~/.claude/`) |
| `codex/` | Global Codex CLI config (deployed to `~/.codex/`) |
| `config/` | Starship prompt, ripgrep defaults |
| `tests/` | 7 test suites (unit, integration, security, packages, functions) |

## Instruction File Layout

| File | Scope | Read by |
|------|-------|---------|
| `AGENTS.md` (root) | This repo | All AI tools (Cursor, Windsurf, etc.) |
| `CLAUDE.md` (root, this file) | This repo | Claude Code only |
| `.github/copilot-instructions.md` | This repo | GitHub Copilot |
| `claude-code/CLAUDE.md` | Global (all projects) | Claude Code (deployed to `~/.claude/`) |
| `codex/AGENTS.md` | Global (all projects) | Codex CLI (deployed to `~/.codex/`) |
| `copilot/copilot-instructions.md` | Global (all projects) | Copilot CLI (deployed to `~/.copilot/`) |
| `agent-prompts/*.md` | Global (all projects) | Shared fragments, deployed to each tool's `prompts/` dir |

Project-specific instructions belong in root files. Global files should contain
only preferences and guardrails that apply across all repositories.

Cross-tool content (communication style, CLI tool preferences, comment policy,
markdown formatting, worktree operational rules) is single-sourced in
`agent-prompts/` and deployed to `~/.claude/prompts/`, `~/.codex/prompts/`, and
`~/.copilot/prompts/` by `bootstrap/symlinks.sh` (whole-directory, so a new
fragment needs no manifest entry). Claude loads it via native
`@~/.claude/prompts/...` imports (guaranteed, inlined at session start); Codex
and Copilot have no import mechanism, so their global files carry a "read these
at session start" directive (best-effort). For that reason security-critical
content stays inlined in every instruction file and remains covered by
`tests/test-consistency.sh`; only preferences and conventions belong in
`agent-prompts/`.

Two inlined exceptions are load-bearing and deliberately not shared:

- The credential deny lists in Guardrails.
- The repo-local `core.hooksPath` prohibition, which used to sit in the
  triplicated Worktrees section. It silently disables gitleaks secret scanning,
  which is not something to deliver best-effort, so single-sourcing the rest of
  that section promoted this one bullet into Guardrails instead. The test
  asserts it verbatim in all three global files.

Publication policy is also per-tool -- what an agent may push or open without
asking differs -- so it stays inlined alongside a pointer to the shared
fragment.

## Deny-list semantics

Guidance for maintaining `claude-code/settings.json`. It lives here rather than in
the globally-deployed `claude-code/CLAUDE.md` because it is repo-maintenance context:
useful when editing the deny lists, dead weight in every unrelated project's session.

`settings.json` has three kinds of deny entries; they do not share matching rules, so trust them differently.

- `Read(<glob>)` / `Edit(<glob>)` -- real glob matching against the `file_path` argument. Covers credential *file shapes* wherever they appear: `**/.env*`, `**/credentials.*`, `**/*.pem`, `**/*.key`, `**/*.tfstate*`, etc. Whole credential *directories* (`~/.ssh`, `~/.aws`, `~/.stripe`, ...) are not listed here -- they are enumerated once in `sandbox.credentials` and `sandbox.filesystem.denyRead`, and mirrored in `agent-hooks/pre-security.sh`. Add a glob here when the risk is a filename pattern; add a path there when the risk is a directory.
  Do NOT add `Write(<glob>)` entries: the file permission check never consults them, and Claude Code warns about every one at startup. `Edit(<glob>)` is the entry that covers all file-editing tools, Write included.
- `Bash(<prefix>:*)` -- prefix match against the command string. `Bash(rm -rf:*)` blocks only commands literally starting with `rm -rf`, not `sudo rm -rf /`, `bash -c 'rm -rf /'`, `env rm -rf /`, `xargs rm -rf`, subshells, or pipes. A tripwire, never a security boundary.
- There is no hook-based Bash scan behind these. `pre-security.sh` guards file-path arguments only; the command-string scan was retired because it could not tell naming a path from opening one (see [docs/sandbox.md](docs/sandbox.md#why-there-is-no-bash-scan)). Credential reads from Bash are gated by `sandbox.credentials`, enforced by bwrap/Seatbelt.

### The ask tier

`permissions.ask` sits between deny and allow: resolution is deny -> ask -> allow, regardless of rule breadth.
That ordering is the whole design -- a narrow `Bash(gh pr create:*)` in ask prompts even though the broad `Bash(gh pr:*)` allow remains, so read-only verbs stay promptless without enumerating them.
Ask entries use the same prefix-match semantics (and the same blind spots) as Bash deny entries.
Do not "simplify" narrow ask entries into the allow list during maintenance: they implement the outward-facing-writes policy in the deployed `claude-code/CLAUDE.md` (mechanics proceed; speech gets drafted).
`gh api` / `glab api` are ask-gated on purpose -- they can POST anything and would otherwise bypass every verb rule.
Keep `settings.json` and `settings.container.json` ask blocks identical; container sessions are where the most autonomous work happens.

### Command frontmatter allowed-tools

A slash command's `allowed-tools:` is a rule surface of its own, not part of `settings.json`.
It is documented here because it borrows the same prefix-match syntax as the entries above and is easy to mistake for them, while resolving differently in every case below.

- **The parenthesised content is one prefix pattern, not a list.** `Bash(git log:*, git tag:*)` matches nothing at all -- not the first prefix, not any of them -- so every command in the group is denied with "This command requires approval". Each prefix needs its own entry: `Bash(git log:*), Bash(git tag:*)`.
- **It is additive over `settings.json`, not a ceiling.** A broken rule falls back to the global allow list rather than blocking the command, which is why a packed group sits unnoticed for as long as `settings.json` happens to grant the same prefixes. Do not read a working command as evidence that its frontmatter parses.
- **`permissions.ask` still wins.** Ask resolves ahead of frontmatter the same way it resolves ahead of allow, so granting `Bash(gh:*)` in a command file does not un-gate `gh pr create`. A command file cannot widen the outward-speech policy.
- The frontmatter parser is lenient about YAML a strict parser rejects: `argument-hint: [a] [b]` is two flow sequences with no separator, and the `allowed-tools` line below it still takes effect. Quote such values anyway, or anything else reading these files as YAML trips on them.

`tests/test-consistency.sh` enforces the first and last points across `claude-code/commands/`.
Each claim here was checked against a live headless session rather than inferred from the docs.

### Three-tier responsibility model

Bash deny entries stay deliberately narrow. Each risk is defended at exactly one tier; do not duplicate across tiers.
The ask tier guards a fourth kind of risk the tiers below do not: *attribution* -- outward speech published under the developer's identity (PR/MR text, review comments, issue posts). No sandbox or server defends that; the prompt is the gate.

- **Tier 1 -- file content (this layer defends).** Credential exposure is caught by the `Read`/`Edit` globs in `settings.json` for filename shapes, by `sandbox.credentials` and `sandbox.filesystem.denyRead` for whole credential directories, and by the `pre-security.sh` path check for both across every hooked tool. The three lists are not copies of each other: only `pre-security.sh` is expected to carry the full set. Authoritative; new file-content guards belong here.
- **Tier 2 -- system state and network (sandbox/host defends).** The container boundary, OS sandbox (bwrap on Linux/WSL2, seatbelt on macOS), and the `sudo:*` deny are the gates. Do NOT add per-binary Bash denies for `iptables`, `systemctl`, `mkfs`, `dd`, `shutdown`, etc. -- they need sudo to do anything meaningful and sudo is already blocked, so each one only adds a redundant prompt.
- **Tier 3 -- remote / shared (server defends).** Trunk protection, required reviews, and push restrictions live on the remote (GitHub branch protection rules). Do NOT simulate with `Bash(git push * main*)` tripwires -- the prefix matcher does not handle inline wildcards reliably, and remote protection is the only authoritative defense against an accidental trunk push.

Adding a new deny entry? Prefer `Read`/`Edit` with a glob when the risk is about file contents; use `Bash(...)` only as a best-effort tripwire for a local-state footgun.

### What stays in the Bash deny list

Local-state footguns where no other layer catches a typo: `rm -rf` variants, `git reset --hard`, `git clean -fdx`/`-fd`, `git filter-branch`/`filter-repo`, recursive `chmod` to dangerous modes, recursive `chown`, plain `git push --force` and `git push -f` (asymmetric -- the safe variant has a separate path), destructive docker ops (`system prune`, `volume rm`), and the `sudo:*` upstream gate. These are friction speed bumps, not security boundaries.

### Force-push policy

`git push --force-with-lease` is allowed -- use it for stacked-PR rebases. The lease refuses to overwrite a ref that has moved since your last fetch, which is the actual safety property worth preserving locally. Plain `git push --force` and `git push -f` stay denied because they have no such check.

### Codex / Copilot parity

By design, Codex CLI and GitHub Copilot CLI get no equivalent Bash deny list -- their config formats expose no per-command deny syntax. Codex relies on its native `sandbox_mode` (`workspace-write` on hosts, `danger-full-access` in containers, where the container itself is the boundary); Copilot relies on interactive permission prompts plus `--deny-tool` flags. Both pick up the shared `pre-security.sh` hook for Tier 1, but not at Claude Code's coverage. On Codex only `apply_patch` is scanned (needs Codex >= 0.123.0); credential-*read* blocking is unavailable at any version, since its `read_file` and `grep` handlers fire no `PreToolUse` hook, and it has no `sandbox.credentials` equivalent. Treat Tier 1's read-side guarantee as Claude-Code-only; see [`docs/agentic-tooling.md`](docs/agentic-tooling.md#coverage-is-not-symmetric-across-tools).
The ask tier is likewise Claude-Code-only: Codex and Copilot see the same `gh`/`glab` binaries but have no ask equivalent, so the outward-speech gate joins the read-side guarantee as asymmetric coverage -- for those tools it rests on the instruction files alone.

## Devcontainer Behavior

Claude Code and Codex CLI are installed as native binaries everywhere, hosts
included -- that is not devcontainer-specific.

The installer auto-detects devcontainers and Codespaces. What is specific to
those environments:
- AI tool configs are copied fresh from dotfiles on every rebuild
- Credential state persists via volume mounts or Codespaces storage
- Shell history, auth tokens, and sessions survive container rebuilds
- MCP configs (in settings.local.json) persist via the same volume mount as other Claude state
- Project-level .mcp.json files persist in the project repo naturally

## Testing Across Platforms

CI tests 13+ platform configurations. When making changes to bootstrap or shell
scripts, consider cross-platform impact: Ubuntu (20.04/22.04/24.04), Debian
(11/12), Alpine (musl), macOS (15/26), and Codespaces simulation.

## Worktree system (wt) -- maintenance map

Repo-maintenance context for the agentic worktree system; the user-facing rules live in the globally deployed instruction files.

- Design: `docs/agentic-worktree-dev-environment.md` (amended in Status); plan and verified evidence log: `planning/2026-08-02-agentic-worktree-system.md`. Where they disagree, the plan wins.
- Implementation: `bin/wt` (single file until the Phase 5 lib split), `git/hooks/post-checkout` (safety net for worktrees created outside wt; chains git-lfs), `shell/completions/wt.bash` and `shell/completions/_wt` (symlinked into place by `bootstrap/completions.sh`; they feed off `wt list --names`), `tests/test-wt.sh` (`make test-wt`).
- Invariants to preserve when editing: provisioning never copies a file whose destination is not gitignored (hard-fail + rollback); `remove` refuses dirty trees and tears down containers by `wt.project`/`wt.slug` labels; worktrees are always created with relative paths; container commands are host-only; no project ever sets repo-local `core.hooksPath`.
- Completion is a three-part contract: the symlink must exist, the command name must be bound to `_wt` at the end of shell startup, and the zsh dump must not be caching an older binding. Check with `zsh -i -c 'print ${_comps[wt]}'`, which must print `_wt` -- a missing symlink, a hijacked name, and a stale dump are three different failures with the same symptom.
  The non-obvious parts:
  - **Carapace owns a colliding `wt` spec** (Windows Terminal's `wt.exe`). It mass-registers every spec via one `compdef`/`complete` call, and `shell/completion.sh` sources it *after* ours, so last-writer-wins silently replaced `wt`. Fixed by appending `wt` to `CARAPACE_EXCLUDES` in `shell/exports.sh`. Keep it in exports, not completion.sh: it must be set before either shell branch runs `carapace _carapace <shell>`, and both `.bashrc` and `.zprofile` source exports first. Append rather than assign -- a devcontainer `remoteEnv` may have excluded other specs deliberately.
  - **`~/.cache/zsh/zcompdump` persists a binding independently of how it was made.** Zinit's turbo-mode plugins load after completion.sh, and the subsequent compinit writes a dump that captures whatever `_comps` held by then. `compinit -C` replays it *without rescanning fpath*, which cuts both ways: it preserves an old carapace binding, and it hides a newly installed completion until the dump is rebuilt. Two guards, because they cover different entry points: `.zshrc` rebuilds when the completions dir is newer than the dump (`-nt`), and `bootstrap/completions.sh` deletes the dump after writing completions. Manual recovery is still `rm -f ~/.cache/zsh/zcompdump`. Do not "simplify" the fpath entry to a plain daily rebuild -- on the cached path it does nothing at all, which is the failure the `-nt` clause exists to prevent.
  - **The full-compinit branch passes `-u` on purpose.** Putting the dir on fpath before compinit also puts it in front of compaudit, which follows the symlinks into the dotfiles checkout. On a WSL2 DrvFs mount every path reports 0777, so the audit would prompt at each shell start and then skip exactly the files the fpath entry exists to load. `-u` accepts them; the tradeoff is that a genuinely world-writable dir on fpath is trusted, which is acceptable for single-user machines and containers and is the reason this is a deliberate flag rather than an oversight.
- `ignore` is the one command that does not call `detect_mode`: its target may be a workspace root sitting *above* several orchestration dirs, which is not a project. It detects layouts (a `repo.git` beside a `wt/`, a `*-worktrees/` sibling) rather than emitting a fixed list, rewrites only the delimited managed block so hand-written rules survive, and is wired into `init` (writes) and `doctor` (reports missing or stale). Doctor's check is orchestration-mode only -- clone mode puts worktrees in a sibling dir that an `.ignore` inside the clone cannot bound. Rationale and the E2BIG failure it prevents: [docs/agentic-worktree-dev-environment.md](docs/agentic-worktree-dev-environment.md#why-the-orchestration-root-needs-an-ignore).
- `WT_SLUG_MAX` (40) is a display budget, not an identity. Changing it must never orphan a worktree already on disk, which is why every name-taking command resolves through `resolve_worktree` -- creation mapping first, then a prefix match against git's own registry -- rather than recomputing the path. `worktree_dest` is the creation mapping only; do not reintroduce it as a lookup.
- Parked: the `WorktreeCreate`/`WorktreeRemove` shims and the `devcontainer *` sandbox exclusion await the in-flight `claude-code/settings.json` rework (plan Phase 4).
