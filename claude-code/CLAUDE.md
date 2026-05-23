# Global Claude Code Instructions

## Guardrails

- No emojis in code, docs, or commit messages
- Use conventional commits; no AI attribution or Co-Authored-By lines
- Never read .env, credentials, secrets, .pem, .key files
- Never access credential directories: ~/.ssh, ~/.aws, ~/.gnupg, ~/.azure, ~/.config/gcloud, ~/.config/gh, ~/.docker, ~/.kube, ~/.config/heroku, ~/.config/doctl, ~/.gradle, ~/.m2, ~/.minikube, ~/.cargo, ~/.gem, ~/.composer, ~/.stripe, ~/.dotfiles-state, ~/.copilot
- Never access credential files: ~/.npmrc, ~/.pypirc, ~/.netrc, ~/.git-credentials, ~/.pgpass, ~/.my.cnf, ~/.mongorc.js, *.tfvars, *.ppk, *.jks, *.keystore, *.pfx, *.p12, settings.local.json
- Deny path traversal patterns (`../`) unless the user explicitly asks and confirms
- Permission hooks enforce credential deny lists in `settings.json`
- The `pre-security.sh` hook blocks access to sensitive paths at runtime
- The `pre-commit-validate.sh` hook enforces conventional commits on `git commit`
- The `pre-code-no-emoji.sh` hook blocks decorative emojis in code files

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

If you are adding a new deny entry, prefer `Read`/`Write`/`Edit` with a glob when the
risk is about file contents, and use `Bash(...)` only as a best-effort tripwire.

## Sandbox boundary

Bash commands run inside an OS-enforced sandbox: Seatbelt on macOS, bubblewrap on
Linux/WSL2. This is a separate layer from `permissions` and applies to every
sandboxed subprocess, not just Claude's file tools.

- `sandbox.filesystem.denyRead` / `denyWrite` are merged with `Read()`/`Write()`
  permission rules into OS path-prefix denies. A `python3 -c "open(...)"` against
  a denied path returns an OS permission error, not data.
- In-project recursive globs (`**/*.pem`, `**/*secret*`, `**/credentials*`, `.env`)
  cannot be promoted to OS denies without blocking the project itself. They still
  fully gate `Read`/`Write`/`Edit`, and `pre-security.sh` substring-scans Bash
  command strings for them. Keep real secrets out of project trees.
- `excludedCommands` (e.g. `obsidian *`) and the residual `Bash(...)` allow list
  are the unsandboxed-fallback path. They go through the normal permission flow.
- Default write boundary is cwd-only. Shell rc files and credential dirs in
  `denyWrite` are blocked at the OS level even if a subprocess tried.
- `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` strips Anthropic and cloud-provider
  credentials from sandboxed-subprocess env vars (`denyRead` only covers files).
- Network access is gated by `network.allowedDomains` via a proxy. The proxy does
  not inspect TLS, so keep the allowlist narrow.

Do not write Bash-hygiene guidance ("avoid here-docs", "no pipes", "no command
substitution") here. The sandbox makes that obsolete; the analyzer no longer
prompts on un-decomposable commands once the OS boundary contains them.

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
