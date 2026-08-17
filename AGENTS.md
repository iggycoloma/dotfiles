# Dotfiles Repository -- Agent Instructions

Canonical, model-neutral instructions for all AI coding tools working in this repository.
The adjacent `CLAUDE.md` imports this file via `@AGENTS.md` and adds only Claude-specific content.

## About This Repo

Portable dotfiles that lay down a productive, agentic coding environment on local
hosts (macOS/Linux), VS Code devcontainers, and GitHub Codespaces. A single
`install.sh` detects the environment and adapts automatically. It is safe to re-run.

This repo provides a **developer-specific** environment, not a project-specific one.
It installs universally useful shell tools (rg, fd, bat, fzf, etc.) and deeply
integrates agentic coding tools (Claude Code, Codex CLI). For project-dependent
tools (gh, docker, kubectl, mise, uv), the repo supplies configuration -- aliases,
completions, state persistence -- but does not install them. Projects bring their
own tooling via `devcontainer.json`; this repo ensures the developer's workflow is
ready when they arrive.

When making changes, respect this boundary: don't add installation logic for tools
that belong to individual projects. Do add configuration, completions, and state
persistence for tools developers commonly encounter.

Tested platforms: Ubuntu (20.04/22.04/24.04), Debian (11/12), Alpine, macOS (15/26),
GitHub Codespaces. CI tests 13+ platform configurations; when changing bootstrap or
shell scripts, consider cross-platform impact.

## Agent instruction architecture

### Sources are authoritative; deployments are outputs

The tracked sources in this repository are the single source of truth for every agent-instruction surface.
The files under `~/.claude`, `~/.codex`, and `~/.copilot` are generated or synchronized outputs of `bootstrap/symlinks.sh` (symlinks on hosts, managed copies in devcontainers) and must not drift silently:
edit the tracked source and redeploy, never the deployed copy.
`bin/prompt-drift.sh` (wired into `make lint`) verifies that deployed instruction files still match their tracked sources;
`bin/settings-drift.sh` does the same for the settings variants.

### Where a rule belongs

- Personal safety, tool choice, writing style, response calibration, and personal workflow live in the personal/shared prompt sources: `claude-code/CLAUDE.md`, `codex/AGENTS.md`, `copilot/copilot-instructions.md`, and the single-sourced fragments in `agent-prompts/`.
- Project-specific instructions belong in repository root files. The globally deployed files carry only preferences and guardrails that apply across all repositories -- repo details placed there load into every unrelated project's session.
- Workspace-specific authority, source order, publication policy, local runtime wrappers, and worktree layout live in the workspace prompt -- the instruction file at the workspace root that sits above individual checkouts.
- Team-owned code, test, canonical command, commit, MR, and review standards live in each repository's root `AGENTS.md`.
- Subtree `AGENTS.md` files contain only expensive-to-rediscover invariants and gotchas unique to that subtree.
- Multi-step or rare procedures use on-demand skills/runbooks, with a short mandatory trigger in an always-loaded file only when reliable activation has been demonstrated.
- Model-neutral policy is canonical in `AGENTS.md`. `CLAUDE.md` imports the adjacent `AGENTS.md` with `@AGENTS.md` and adds only Claude-specific calibration.

### How harnesses load these files

- Codex builds an instruction chain from its detected project root toward the working directory, loading at most one recognized instruction file per directory (`AGENTS.override.md`, then `AGENTS.md`), concatenated root-first under a combined size cap (32 KiB by default). A parent directory above the detected project root cannot be assumed to load, so a repository root `AGENTS.md` must be self-contained.
- Claude Code discovers `CLAUDE.md` files in parent directories of the working directory (loaded in full at launch) and in subdirectories (loaded on demand when files there are read), and supports `@file` imports, including `@AGENTS.md`.
- Claude imports organize content but do not make it task-conditional or reduce context cost: imported files are inlined at session start.
- A linked side document is not automatic Codex context. Keep always-required cross-harness rules in `AGENTS.md`; put conditional procedures outside it only behind an explicit trigger or a tested native skill.
- More-specific instructions override broader ones in both harnesses. Avoid contradictory copies: keep one canonical statement per rule and reference it.

### File map

| File | Scope | Read by |
|------|-------|---------|
| `AGENTS.md` (root, this file) | This repo | All AI tools; Claude via the `@AGENTS.md` import in `CLAUDE.md` |
| `CLAUDE.md` (root) | This repo | Claude Code only: `@AGENTS.md` plus Claude-specific content |
| `.github/copilot-instructions.md` | This repo | GitHub Copilot |
| `claude-code/CLAUDE.md` | Global (all projects) | Claude Code (deployed to `~/.claude/`) |
| `codex/AGENTS.md` | Global (all projects) | Codex CLI (deployed to `~/.codex/`) |
| `copilot/copilot-instructions.md` | Global (all projects) | Copilot CLI (deployed to `~/.copilot/`) |
| `agent-prompts/*.md` | Global (all projects) | Shared fragments, deployed to each tool's `prompts/` dir |

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
- The repo-local `core.hooksPath` prohibition in the globally-deployed files.
  It silently disables gitleaks secret scanning, which is not something to
  deliver best-effort, so it stays inlined per tool and the test asserts it
  verbatim in all three global files.

Publication policy is also per-tool -- what an agent may push or open without
asking differs -- so it stays inlined alongside a pointer to the shared
fragment.

## Guardrails

- No emojis in code, docs, or commit messages
- Use conventional commits; no AI attribution or Co-Authored-By lines
- Never read .env, credentials, secrets, .pem, .key files
- Never access credential directories: ~/.ssh, ~/.aws, ~/.gnupg, ~/.azure, ~/.config/gcloud, ~/.config/gh, ~/.config/glab-cli, ~/.docker, ~/.kube, ~/.config/heroku, ~/.config/doctl, ~/.gradle, ~/.m2, ~/.minikube, ~/.cargo, ~/.gem, ~/.composer, ~/.stripe, ~/.dotfiles-state, ~/.copilot
- Never access credential files: ~/.npmrc, ~/.pypirc, ~/.netrc, ~/.git-credentials, ~/.pgpass, ~/.my.cnf, ~/.mongorc.js, *.tfvars, *.ppk, *.jks, *.keystore, *.pfx, *.p12, settings.local.json, ~/.claude/.credentials.json
- Deny path traversal patterns (`../`) unless the user explicitly asks and confirms

## Quality

- All shell scripts must pass `make lint` (shellcheck) before merging; CI enforces this
- Run `make test` to execute the full test suite locally (unit + packages + integration)
- `make test-unit` / `make test-packages` / `make test-integration` run suites individually
- Run `shellcheck` on any new or modified `.sh` file before committing

## Preferred CLI Tools

Use these tools when available instead of standard Unix alternatives:

| Instead of | Use | When |
|-----------|-----|------|
| `grep` (pattern search) | `rg` (ripgrep) | Text/regex search across files |
| `grep` (structural) | `sg` (ast-grep) | Finding code patterns by AST structure |
| `find` | `fd` | Finding files by name/pattern |
| `diff` | `difft` (difftastic) | Comparing files (AST-aware, ignores formatting noise) |
| `sed` | `sd` | Find/replace with PCRE regex |
| `cat` (highlighted) | `bat` | Viewing files with syntax highlighting |
| `wc -l` / `cloc` | `scc` | Code statistics (LOC, complexity, languages) |
| manual YAML editing | `yq` | YAML/TOML/XML queries and edits (preserves comments) |
| `jq` | `jq` | JSON processing (keep using jq, it's the standard) |
| `df` | `duf` | Disk free with color-coded bars |
| `du` | `dust` | Directory disk usage as a visual tree |
| `ps` | `procs` | Process viewer with color and search |
| `time` | `hyperfine` | Benchmarking commands with statistical analysis |

## Command legibility (permissions, security, observability)

Permission matching and the session/audit log both operate on the literal command
string.
Keep that string an honest record of what runs:
it is both the realtime gate and the after-the-fact audit trail,
and both go blind to the same thing -- indirection.

- Prefer built-in file-search and edit tools over shelling out when reading,
  searching, or editing files.
  They need no permission prompt, produce structured output, and emit a typed log
  event instead of a raw shell string.
- Keep commands literal.
  Do NOT hide a path, filename, or credential behind a variable, `base64`/`xxd`,
  glob-indirection, `eval`, command substitution `$(...)`, or a pipe into a shell
  (`... | sh`).
  These defeat the scan at runtime AND make the log unsearchable and
  non-reproducible afterward.
- Complexity is fine; indirection is not.
  A long but literal pipeline (`git log --format=%an | sort | uniq -c | sort -rn`)
  is fully analyzable and is a single clean log line -- prefer it over many opaque
  micro-calls.
- Only reach for dynamic or indirect syntax when the operation is genuinely
  impossible otherwise (a real pipeline, a loop over discovered items).
  When you must, keep any sensitive path or credential literal, and note in one
  line why the wrapper is necessary.

## Security Model

Defense-in-depth across multiple layers:

- **Secret scanning**: gitleaks pre-commit hook on all repos via `core.hooksPath`
- **Credential blocking**: ~50 sensitive file/directory patterns blocked in AI tool configs and hooks
- **Conventional commits**: enforced globally; AI attribution and Co-Authored-By blocked
- **SSH commit signing**: auto-detected from SSH agent (prefers ed25519)
- **Path traversal**: blocked unless explicitly approved
- **MCP posture**: No MCP servers installed by default. MCP servers run as child processes with full filesystem/network access and bypass credential deny lists. Do not install MCPs without explicit user request. MCP auth tokens belong in tool-specific local config (e.g., settings.local.json), never in dotfiles-tracked files.
- **Tool-specific deny lists**: follow a three-tier model -- file content defended locally, system/network defended by sandbox + `sudo:*`, remote/shared defended by branch protection. See `CLAUDE.md` "Deny-list semantics" for the full rationale and what stays in vs out of the Bash deny list.

## Installation Toggles

These environment variables control what `install.sh` installs:

| Variable | Effect |
|----------|--------|
| `DOTFILES_NO_AI_TOOLS=1` | Skip agentic CLIs, ast-grep, difftastic, and AI config |
| `DOTFILES_NO_ATUIN=1` | Skip atuin and bash-preexec |
| `DOTFILES_NO_GIT_HOOKS=1` | Skip global git hooks |
| `DOTFILES_NO_STATE_PERSISTENCE=1` | Skip state persistence tier detection |
| `DOTFILES_NO_SSH_SIGNING=1` | Skip SSH commit signing auto-detection |

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

## Working Style

- Keep changes minimal and focused; do not refactor unrelated code
- Run `make lint` and relevant tests after changes; report what was run
- If asked for a review, prioritize bugs/regressions/security issues first, then style
