# Global Claude Code Instructions

## Guardrails

- No emojis in code, docs, or commit messages
- Use conventional commits; no AI attribution or Co-Authored-By lines
- Never read .env, credentials, secrets, .pem, .key files
- Never access credential directories: ~/.ssh, ~/.aws, ~/.gnupg, ~/.azure, ~/.config/gcloud, ~/.config/gh, ~/.config/glab-cli, ~/.docker, ~/.kube, ~/.config/heroku, ~/.config/doctl, ~/.gradle, ~/.m2, ~/.minikube, ~/.cargo, ~/.gem, ~/.composer, ~/.stripe, ~/.dotfiles-state, ~/.copilot
- Never access credential files: ~/.npmrc, ~/.pypirc, ~/.netrc, ~/.git-credentials, ~/.pgpass, ~/.my.cnf, ~/.mongorc.js, *.tfvars, *.ppk, *.jks, *.keystore, *.pfx, *.p12, settings.local.json
- Deny path traversal patterns (`../`) unless the user explicitly asks and confirms
- Permission hooks enforce credential deny lists in `settings.json`
- The `pre-security.sh` hook blocks access to sensitive paths at runtime
- The `pre-code-no-emoji.sh` hook blocks decorative emojis in code files
- Commit messages are enforced by git's `commit-msg` hook (wired via `core.hooksPath`), not by a PreToolUse agent hook

## Deny-list semantics

`settings.json` has three kinds of deny entries; they do not all use the same matching
rules, so treat them with different confidence.

- `Read(<glob>)` / `Write(<glob>)` / `Edit(<glob>)` -- real glob matching against the
  `file_path` argument. These are the primary boundary for credential paths; the list
  covers `.env*`, `~/.ssh/**`, `~/.aws/**`, etc.
- `Bash(<prefix>:*)` -- prefix match against the command string. `Bash(rm -rf:*)` only
  blocks commands that literally start with `rm -rf`; it does not catch `sudo rm -rf /`,
  `bash -c 'rm -rf /'`, `env rm -rf /`, `xargs rm -rf`, or subshells / pipes. Useful as
  a tripwire but never relied on as a security boundary.
- The real defense for dangerous Bash commands is the `pre-security.sh` hook (which
  scans the full command string for sensitive-path substrings and sensitive-directory
  access) plus the credential glob rules above.

### Three-tier responsibility model

Bash deny entries are kept deliberately narrow. Each risk is defended at exactly one
tier; do not duplicate across tiers.

- **Tier 1 -- file content (this layer defends).** Credential exposure is caught by
  `Read`/`Write`/`Edit` glob denies in `settings.json` plus the substring scan in
  `pre-security.sh`. Authoritative. New file-content guards belong here.
- **Tier 2 -- system state and network (sandbox/host defends).** Container boundary,
  OS sandbox (bwrap on Linux/WSL2, seatbelt on macOS), and the `sudo:*` deny entry are
  the gates. Do NOT add per-binary Bash denies for `iptables`, `systemctl`, `mkfs`,
  `dd`, `shutdown`, etc. -- they all need sudo to do anything meaningful, and sudo is
  already blocked. Adding them just creates redundant prompts.
- **Tier 3 -- remote / shared (server defends).** Trunk protection, required reviews,
  and push restrictions are configured on the remote (GitHub branch protection rules).
  Do NOT simulate with `Bash(git push * main*)` glob-prefix tripwires -- the prefix
  matcher does not support inline wildcards reliably, and remote protection is the
  only authoritative defense against an accidental trunk push.

### What stays in the Bash deny list

Local-state footguns where no other layer catches a typo: `rm -rf` variants,
`git reset --hard`, `git clean -fdx`/`-fd`, `git filter-branch`/`filter-repo`,
recursive `chmod` to dangerous modes, recursive `chown`, the plain `git push --force`
and `git push -f` (asymmetric -- the safe variant has a separate path), destructive
docker ops (`system prune`, `volume rm`), and the `sudo:*` upstream gate. These are
friction speed bumps, not security boundaries.

### Force-push policy

`git push --force-with-lease` is allowed. Use it for stacked-PR rebases -- the lease
refuses to overwrite a ref that has moved since your last fetch, which is the actual
safety property worth preserving locally. Plain `git push --force` and `git push -f`
stay denied because they have no such check.

### Codex / Copilot parity

By design, Codex CLI and GitHub Copilot CLI do not get an equivalent Bash deny list.
Their config formats do not expose per-command deny syntax; Codex relies on its
native `sandbox_mode` setting (`workspace-write` on hosts, `danger-full-access` in
containers where the container itself is the boundary), and Copilot relies on
interactive permission prompts plus `--deny-tool` CLI flags. Both pick up the shared
`pre-security.sh` hook for Tier 1.

If you are adding a new deny entry, prefer `Read`/`Write`/`Edit` with a glob when the
risk is about file contents, and use `Bash(...)` only as a best-effort tripwire for a
Tier-A local-state footgun.

## Skill trigger precedence

Several skills have overlapping triggers. When multiple match, apply this order:

- `review-pr` vs `security-audit`: prefer `review-pr` unless the user explicitly asks
  for a security audit or the diff is clearly security-focused (auth/crypto/secrets).
  Incidental touches to a file in one of those areas do not promote to `security-audit`.
- `debug` vs everything else: `debug` takes precedence only when the user pastes a
  stack trace, stderr block, or failing test output. "The UI looks wrong" is not
  `debug`.
- `fix-issue` vs `debug`: `fix-issue` wins when the user references a filed GitHub
  issue (#NNN or issue URL). Without one, stay in `debug`.

## MCP Servers

MCP servers are NOT installed by dotfiles. Claude Code's built-in tools (Bash, Read,
Write, Edit, Glob, Grep, WebFetch, WebSearch) cover most workflows without the context
overhead of MCP tool descriptions.

If an MCP server is already configured (in settings.local.json or .mcp.json), use it.
Do not install or configure new MCP servers without explicit user request.

Security notes:
- MCP servers run as child processes with full filesystem and network access
- They bypass settings.json deny rules (credential blocking does not apply to MCPs)
- Treat .mcp.json files as security-sensitive (they configure arbitrary child processes)
- Never store MCP auth tokens in settings.json (use settings.local.json, which is not
  tracked by dotfiles)

## Tool Use Discipline

- NEVER use Bash to run `rg`, `grep`, or `find` — use the built-in Grep and Glob tools instead. They require no permission prompts and produce cleaner output.
- Only use Bash for CLI tools that have no built-in equivalent (e.g., `sg`, `scc`, `yq`, `shellcheck`).
- Avoid wrapping tool calls in Bash `for`/`while` loops. Use glob patterns to search across multiple files in a single Grep or Glob call. If a loop is truly needed, the command starts with `for`, not the inner tool — so `bash(rg:*)` rules won't match.
- The built-in Grep tool IS ripgrep — same engine, same speed as `rg`, plus no permission prompt, structured output, and a typed log event instead of a raw shell string. There is nothing to "redirect for speed"; do not shell out to `rg`/`grep`/`find` to go faster. Steer it via its parameters (`glob`, `type`, `-i`, `-A`/`-B`/`-C`, `output_mode`), not config — it does not read your shell's ripgrep aliases or rc file.
- Keep Bash commands literal so the permission matcher, `pre-security.sh`, and the session log all see what actually runs. Do NOT hide paths, filenames, or credentials behind variables, `base64`/`xxd`, `eval`, command substitution `$(...)`, or a pipe into a shell (`... | sh`). Length is fine; indirection is not. See `AGENTS.md` "Command legibility" for the full rationale — the realtime gate and the audit trail share the same blind spot.

## Preferred CLI Tools

Use these tools when available instead of standard Unix alternatives:

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

## Structural Code Search (ast-grep)

When searching for code patterns like "all function calls to X" or "all imports of Y",
prefer `sg` over `rg`. Examples:

- `sg --pattern 'console.log($$$)' --lang js` -- find all console.log calls
- `sg --pattern 'import $_ from "react"' --lang tsx` -- find React imports
- Use `sg --help` to learn more patterns

## File Watching

- Use `watchexec` for auto-test/rebuild loops when iterating on changes
- Example: `watchexec -e py -- pytest tests/`

## Markdown formatting (semantic line breaks)

Default for `.md` and other long-form prose files (CHANGELOG, ADRs, design docs): use **semantic line breaks** — one sentence per line, with breaks at major clause boundaries (after a comma before a long phrase, after a colon before a list, before each `AND`/`WHEN`/`THEN` in scenario blocks). Do NOT hard-wrap to a fixed column.

Why: renderers reflow anyway, so column wrapping serves no display purpose. Sentence-per-line gives clean diffs (one edit changes one line, not three) and is more pleasant to author than counting columns.

Apply this to new content and to sections you are substantively rewriting. Do NOT reflow files that are otherwise untouched — that produces large no-op diffs that bury real changes.

Exceptions, in priority order:
1. **Project tooling wins.** If a repo has `.editorconfig`, `.prettierrc`, `.markdownlint*.json`, or similar configured with a different policy (e.g. `proseWrap: "always"` and `printWidth: 80`), follow that. Prettier `proseWrap: "preserve"` and markdownlint `MD013: false` are the configurations compatible with semantic line breaks; their absence does not block this default but their presence with a stricter policy does.
2. **Code blocks, tables, and frontmatter are mechanical.** Don't reformat them as prose.
3. **Commit messages and PR descriptions** follow their own conventions (subject < 72 chars, body wrapped to ~72) — semantic breaks do not apply there.

When in doubt, match the surrounding file's existing style rather than introducing a third pattern.
