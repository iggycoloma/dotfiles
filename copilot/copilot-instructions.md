# Global Instructions

## Guardrails

- No emojis in code, docs, or commit messages
- Use conventional commits; no AI attribution or Co-Authored-By lines
- Never read .env, credentials, secrets, .pem, .key files
- Never access credential directories: ~/.ssh, ~/.aws, ~/.gnupg, ~/.azure, ~/.config/gcloud, ~/.config/gh, ~/.docker, ~/.kube, ~/.config/heroku, ~/.config/doctl, ~/.gradle, ~/.m2, ~/.minikube, ~/.cargo, ~/.gem, ~/.composer, ~/.stripe, ~/.dotfiles-state, ~/.copilot
- Never access credential files: ~/.npmrc, ~/.pypirc, ~/.netrc, ~/.git-credentials, ~/.pgpass, ~/.my.cnf, ~/.mongorc.js, *.tfvars, *.ppk, *.jks, *.keystore, *.pfx, *.p12, settings.local.json
- Deny path traversal patterns (`../`) unless explicitly confirmed

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

Your tool's permission checks, the `pre-security.sh` path scan, and the session/audit log all read the literal command string -- the realtime gate and the audit trail share the same blind spot, so keep that string an honest record of what runs.

- Prefer built-in file-search and edit tools over shelling out for reading, searching, and editing files -- no permission prompt, structured output, and a typed log event instead of a raw shell string.
- Keep commands literal: do not hide paths, filenames, or credentials behind variables, `base64`/`xxd`, `eval`, command substitution `$(...)`, or a pipe into a shell (`... | sh`). These defeat the scan at runtime and make the log unsearchable and non-reproducible afterward.
- Complexity is fine; indirection is not. A long but literal pipeline is fully analyzable and is a single clean log line -- prefer it over many opaque micro-calls.
- Reserve dynamic or indirect syntax for when the operation is genuinely impossible otherwise; when you must, keep any sensitive path or credential literal and note in one line why the wrapper is necessary.

## MCP Servers

MCP servers are not installed by dotfiles. If one is configured, use it. Do not install
new MCP servers without explicit user request. MCP servers bypass credential deny lists.

## Working Style

- Keep changes minimal and focused; do not refactor unrelated code
- Run relevant tests/lint after changes when practical and report what was run
- If asked for a review, prioritize bugs/regressions/security issues first, then style

## Markdown formatting (semantic line breaks)

Default for `.md` and other long-form prose files: use semantic line breaks -- one sentence per line, with breaks at major clause boundaries. Do NOT hard-wrap to a fixed column. Apply to new content and sections being substantively rewritten; do not reflow otherwise-untouched files (large no-op diffs bury real changes).

Project tooling wins: if `.editorconfig`, `.prettierrc`, or markdownlint configures a different policy, follow the repo's setting. Prettier `proseWrap: "preserve"` and markdownlint `MD013: false` are the compatible settings. Code blocks, tables, and frontmatter are mechanical, not prose. Commit messages and PR descriptions follow their own conventions (~72-char body wrap) and are out of scope.
