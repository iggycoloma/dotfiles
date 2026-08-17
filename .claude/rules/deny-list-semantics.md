---
paths:
  - "claude-code/settings*.json"
  - "claude-code/commands/**/*.md"
---

# Deny-list semantics

Guidance for maintaining `claude-code/settings.json` and command frontmatter.
It is a path-scoped rule rather than root-CLAUDE.md content because it is repo-maintenance context:
essential when editing the deny lists or slash commands, dead weight in every other session.

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
