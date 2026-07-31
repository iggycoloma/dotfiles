# Global Claude Code Instructions

## Guardrails

- No emojis in code, docs, or commit messages
- Use conventional commits; no AI attribution or Co-Authored-By lines
- Never read .env, credentials, secrets, .pem, .key files
- Never access credential directories: ~/.ssh, ~/.aws, ~/.gnupg, ~/.azure, ~/.config/gcloud, ~/.config/gh, ~/.config/glab-cli, ~/.docker, ~/.kube, ~/.config/heroku, ~/.config/doctl, ~/.gradle, ~/.m2, ~/.minikube, ~/.cargo, ~/.gem, ~/.composer, ~/.stripe, ~/.dotfiles-state, ~/.copilot
- Never access credential files: ~/.npmrc, ~/.pypirc, ~/.netrc, ~/.git-credentials, ~/.pgpass, ~/.my.cnf, ~/.mongorc.js, *.tfvars, *.ppk, *.jks, *.keystore, *.pfx, *.p12, settings.local.json, ~/.claude/.credentials.json
- Deny path traversal patterns (`../`) unless the user explicitly asks and confirms

Enforcement: `settings.json` permission rules carry the credential deny lists and `pre-security.sh` blocks the same paths for the file tools; `sandbox.credentials` blocks them for Bash subprocesses at the OS level. `pre-code-no-emoji.sh` blocks decorative emojis in code files, and git's `commit-msg` hook (wired via `core.hooksPath`) enforces commit messages -- not a PreToolUse agent hook.

## Memory

Never write to `~/.claude/projects/*/memory/`, including its `MEMORY.md` index.
That surface is untracked, unreviewable, and injected into context unread; it stays empty.
`settings.json` denies `Write` and `Edit` there, and leaves `Read` open so anything already present stays auditable.

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

## Preferred CLI Tools

Use these instead of the standard Unix alternatives when available:

| Instead of | Use | When |
|-----------|-----|------|
| `grep` (pattern search) | `rg` (ripgrep) | Text/regex search across files |
| `grep` (structural) | `sg` (ast-grep) | Finding code patterns by AST structure (function calls, imports, class definitions) |
| `find` | `fd` | Finding files by name/pattern |
| `diff` | `difft` (difftastic) | Comparing files (AST-aware, ignores formatting noise) |
| `sed` | `sd` | Find/replace with PCRE regex (no escaping hell) |
| `cat` (highlighted) | `bat` | Viewing files with syntax highlighting |
| `wc -l` / `cloc` | `scc` | Code statistics (LOC, complexity, languages) |
| manual YAML editing | `yq` | YAML/TOML/XML queries and edits (preserves comments/formatting) |
| `jq` | `jq` | JSON processing (keep using jq, it's the standard) |
| `df` | `duf` | Disk free with color-coded bars |
| `du` | `dust` | Directory disk usage as a visual tree |
| `ps` | `procs` | Process viewer with color and search |
| `time` | `hyperfine` | Benchmarking commands with statistical analysis |

Reach for `sg` over `rg` on structural questions ("all calls to X", "all imports of Y"): `sg --pattern 'console.log($$$)' --lang js`, `sg --pattern 'import $_ from "react"' --lang tsx`, `sg --help` for more.

Use `watchexec` for auto-test/rebuild loops: `watchexec -e py -- pytest tests/`.

## Comments: prefer self-explanatory code

Reach for a comment only when the code cannot explain itself.
Before writing or keeping one, try in order:

1. **Fold it into a name.** Rename the symbol, or extract a named helper or constant, until the comment is redundant (`codeOf` -> `mappedErrorCodeFor`).
2. **Fold it into the type.** A precise type, enum, or narrowed signature often says what the comment was compensating for.
3. **Delete it** if the name, signature, or body already carries the content.

Keep a comment only when it explains *why*, not *what*: non-obvious rationale or a rejected alternative; external constraints and gotchas (ordering/lifecycle, load-order, framework semantics not visible locally, concurrency hazards); a workaround and its reason; a pointer to the ticket, spec, or upstream issue that motivates the code.

Drop as noise: restatements of the name, signature, or next line; narration of self-descriptive code; redundant doc blocks on helpers whose name and body are already clear; section-divider banners; commented-out code.

Scope: applies to code you write and to files you are already substantively editing.
Do not churn otherwise-untouched files unless asked for a comment pass.
On such a pass, flag rather than rewrite a collaborator's files that already meet this bar.

## Markdown formatting (semantic line breaks)

Default for `.md` and other long-form prose files (CHANGELOG, ADRs, design docs): use **semantic line breaks** -- one sentence per line, breaking at major clause boundaries (after a comma before a long phrase, after a colon before a list, before each `AND`/`WHEN`/`THEN` in scenario blocks). Do NOT hard-wrap to a fixed column: renderers reflow anyway, so column wrapping serves no display purpose, while sentence-per-line gives clean diffs (one edit changes one line, not three).

Apply to new content and to sections you are substantively rewriting. Do NOT reflow otherwise-untouched files -- large no-op diffs bury real changes.

Exceptions, in priority order:
1. **Project tooling wins.** A repo's `.editorconfig`, `.prettierrc`, `.markdownlint*.json`, or similar configured with a different policy (e.g. `proseWrap: "always"` and `printWidth: 80`) overrides this default. Prettier `proseWrap: "preserve"` and markdownlint `MD013: false` are the compatible settings; their absence does not block this default, but a stricter policy's presence does.
2. **Code blocks, tables, and frontmatter are mechanical.** Don't reformat them as prose.
3. **Commit messages** wrap the body to ~72 columns (subject < 72 chars) -- git and terminal tooling do not reflow, so source width is display width.
4. **PR, issue, and comment bodies on GitHub do NOT wrap.** GitHub renders them as GFM with hardbreaks enabled, so every newline becomes a `<br>` and a 72-column source displays as a narrow ragged column. Let paragraph lines run long, or use one sentence per line; separate paragraphs with blank lines. This is deliberately the opposite of the commit-message rule above, and applies only to text destined for the GitHub web UI -- `.md` files rendered from the repo do reflow and follow the default.

When in doubt, match the surrounding file's existing style rather than introducing a third pattern.

## Skill trigger precedence

Several skills have overlapping triggers. When multiple match, apply this order:

- `review-pr` over `security-audit` unless the user explicitly asks for a security audit or the diff is clearly security-focused (auth/crypto/secrets). Incidental touches to a file in one of those areas do not promote to `security-audit`.
- `debug` over everything else only when the user pastes a stack trace, stderr block, or failing test output. "The UI looks wrong" is not `debug`.
- `fix-issue` over `debug` when the user references a filed GitHub issue (#NNN or issue URL). Without one, stay in `debug`.
