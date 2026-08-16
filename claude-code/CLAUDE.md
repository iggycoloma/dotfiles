# Global Claude Code Instructions

## Guardrails

- No emojis in code, docs, or commit messages
- Use conventional commits; no AI attribution or Co-Authored-By lines
- Never read .env, credentials, secrets, .pem, .key files
- Never access credential directories: ~/.ssh, ~/.aws, ~/.gnupg, ~/.azure, ~/.config/gcloud, ~/.config/gh, ~/.config/glab-cli, ~/.docker, ~/.kube, ~/.config/heroku, ~/.config/doctl, ~/.gradle, ~/.m2, ~/.minikube, ~/.cargo, ~/.gem, ~/.composer, ~/.stripe, ~/.dotfiles-state, ~/.copilot
- Never access credential files: ~/.npmrc, ~/.pypirc, ~/.netrc, ~/.git-credentials, ~/.pgpass, ~/.my.cnf, ~/.mongorc.js, *.tfvars, *.ppk, *.jks, *.keystore, *.pfx, *.p12, settings.local.json, ~/.claude/.credentials.json
- Deny path traversal patterns (`../`) unless the user explicitly asks and confirms
- Never set repo-local `core.hooksPath`: it silently disables the global secret-scanning and commit-message hooks

Enforcement: `settings.json` permission rules carry the credential deny lists and `pre-security.sh` blocks the same paths for the file tools; `sandbox.credentials` blocks them for Bash subprocesses at the OS level. `pre-code-no-emoji.sh` blocks decorative emojis in code files, and git's `commit-msg` hook (wired via `core.hooksPath`) enforces commit messages -- not a PreToolUse agent hook.

## Outward-facing writes

**Mechanics proceed; speech gets drafted.** The gate is not whether an action leaves
this machine -- it is whether the result becomes an utterance attributed to me.

- **Proceeds without asking:** local files, branches, commits, worktrees, and
  `git push` to origin. Plain force-push stays denied; `--force-with-lease` remains
  allowed (the lease is the safety check).
- **Always drafted for my approval:** PR/MR create and edit, code review comments
  and approvals, issue create and comment, Slack messages, Linear writes, Notion
  pages, email, calendar invites.
- Compose the full text, show it, stop. Do not run `gh pr create`, `glab mr create`,
  or their `comment` / `review` / `note` / `approve` equivalents.

Enforcement: `settings.json` puts the `gh` / `glab` write verbs and `gh api` /
`glab api` in `permissions.ask`, so they prompt even though the broader
`Bash(gh pr:*)` and `Bash(glab mr:*)` allows remain. MCP writes (Slack, Linear,
Notion) are deliberately not allowlisted, so they prompt by default.

## Memory

Never write to `~/.claude/projects/*/memory/`, including its `MEMORY.md` index.
That surface is untracked, unreviewable, and injected into context unread; it stays empty.
`settings.json` denies `Edit` there -- which covers every file-editing tool, Write included -- and leaves `Read` open so anything already present stays auditable.

When something seems worth persisting, propose it rather than saving it: the fact in one line, why the repo or git history does not already carry it, and a recommended destination with the reason.
Then wait -- never pick the file yourself.

| Destination | Loaded | Fits |
|---|---|---|
| `~/.claude/CLAUDE.md` | every session, everywhere | short cross-project rules |
| `<project>/CLAUDE.md` | every session in that tree | project conventions and protocols |
| skill under `~/.claude/skills/` | on demand | multi-step procedures |
| Obsidian vault `Atlas/` | when explicitly read | knowledge, project state, research |

Prefer the cheapest surface that works.
CLAUDE.md is always-on context, so anything past a few lines belongs in the vault or a skill with a one-line pointer.
Live state -- ticket status, ownership, open MRs -- goes to Linear or the vault, never a rules file: it goes stale silently.

## MCP Servers

MCP servers are NOT installed by dotfiles -- the built-in tools (Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch) cover most workflows without the context overhead of MCP tool descriptions. If one is already configured (in settings.local.json or .mcp.json), use it; do not install or configure new servers without explicit user request.

Security: MCP servers run as child processes with full filesystem and network access, and they bypass settings.json deny rules -- credential blocking does not apply to them. Treat .mcp.json files as security-sensitive, since they configure arbitrary child processes. Never store MCP auth tokens in settings.json; use settings.local.json, which dotfiles does not track.

## Tool Use Discipline

- Prefer the built-in Grep and Glob tools over shelling out to `rg`, `grep`, or `find`, when they are available. Grep IS ripgrep: same engine, same speed, plus no permission prompt, structured output, and a typed log event instead of a raw shell string. Steer it with its parameters (`glob`, `type`, `-i`, `-A`/`-B`/`-C`, `output_mode`), not config -- it does not read your shell's ripgrep aliases or rc file.
- Availability varies by context: background jobs and some subagent profiles ship a reduced tool set, so a rule that assumes Grep exists is unfollowable where it does not. Check what you have rather than assuming. When Grep and Glob are absent, `rg` and `fd` through Bash are the correct fallback, not a rule violation -- the allow list covers them so they run without prompting. Say so once when you fall back, so the choice is visible rather than looking like drift.
- Use Bash for CLI tools with no built-in equivalent (`sg`, `scc`, `yq`, `shellcheck`) regardless of what else is available.
- Do not wrap searches in Bash `for`/`while` loops -- one glob pattern in a single Grep/Glob call, or one `rg`/`fd` invocation. A loop's command string starts with `for`, not the inner tool, so `Bash(rg:*)` never matches and every iteration prompts.
- Keep Bash commands literal so the permission matcher and the session log both see what actually runs. Do NOT hide paths, filenames, or credentials behind variables, `base64`/`xxd`, `eval`, command substitution `$(...)`, or a pipe into a shell (`... | sh`). Length is fine; indirection is not -- the realtime gate and the audit trail share the same blind spot.

## Shared conventions

Cross-tool conventions (preferred CLI tools, code-comment policy, markdown formatting) are single-sourced in the dotfiles `agent-prompts/` directory and imported here:

@~/.claude/prompts/engineering-conventions.md

## Communication style

@~/.claude/prompts/writing-style.md

Claude-specific corrections -- the baseline bias runs verbose and lexically elevated; actively counteract it:

- Prefer the simplest precise term; do not reach for sophisticated vocabulary when a common word is equally precise.
- Do not turn straightforward engineering observations into named principles or lengthy taxonomies.
- Stop once the question is adequately answered.

## Skill trigger precedence

Several skills have overlapping triggers. When multiple match, apply this order:

- `review-pr` over `security-audit` unless the user explicitly asks for a security audit or the diff is clearly security-focused (auth/crypto/secrets). Incidental touches to a file in one of those areas do not promote to `security-audit`.
- `debug` over everything else only when the user pastes a stack trace, stderr block, or failing test output. "The UI looks wrong" is not `debug`.
- `fix-issue` over `debug` when the user references a filed issue or ticket (#NNN, an issue URL, or a tracker key like ENG-123). Without one, stay in `debug`.
- Any diff-scoped review over `systems-review`. A change under review is always reviewed as a change; `systems-review` takes over only when the unit named is a subsystem rather than a diff. It also outranks `refactor` and `optimize` in the other direction -- when the question is which mechanism enforces an invariant, it is not a cleanup or a slowdown.

## Worktrees (parallel agent work)

@~/.claude/prompts/worktrees.md

Claude-specific publication policy, which overrides nothing above but is not shared because it differs per tool:

- Publication policy: commit and push freely per Outward-facing writes above; PRs stay drafted -- compose the text, show it, and let the human run `gh pr create` or grant it explicitly for the task.
