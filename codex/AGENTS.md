# Codex Global Instructions

## Core Guardrails

- Never access secrets or credential files without explicit user approval
- Treat these paths as sensitive: `.env*`, `credentials.json`, `.credentials`, `secrets.yaml`, `secrets.json`, `*.pem`, `*.key`, `*.p12`, `*.pfx`
- Never access credential directories: `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.azure`, `~/.config/gcloud`, `~/.config/gh`, `~/.docker`, `~/.kube`, `~/.config/heroku`, `~/.config/doctl`, `~/.gradle`, `~/.m2`, `~/.minikube`, `~/.cargo`, `~/.gem`, `~/.composer`, `~/.stripe`, `~/.dotfiles-state`, `~/.copilot`
- Never access credential files: `~/.npmrc`, `~/.pypirc`, `~/.netrc`, `~/.git-credentials`, `~/.pgpass`, `~/.my.cnf`, `~/.mongorc.js`, `*.tfvars`, `*.ppk`, `*.jks`, `*.keystore`, `*.pfx`, `*.p12`, `settings.local.json`
- Deny path traversal patterns (for example paths containing `../`) unless the user explicitly asks and confirms
- Do not add decorative emoji characters to code, docs, or commit messages
- Use conventional commits and do not include AI attribution or `Co-Authored-By` lines

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

## MCP Servers

MCP servers are not installed by dotfiles. If an MCP server is already configured, use
it. Do not install or configure new MCP servers without explicit user request.

MCP servers run as child processes with full filesystem and network access and bypass
the credential deny lists above.

## Working Style

- Keep changes minimal and focused; do not refactor unrelated code
- Run relevant tests/lint after changes when practical and report what was run
- If asked for a review, prioritize bugs/regressions/security issues first, then style

## Markdown formatting (semantic line breaks)

Default for `.md` and other long-form prose files: use semantic line breaks -- one sentence per line, with breaks at major clause boundaries. Do NOT hard-wrap to a fixed column. Apply to new content and sections being substantively rewritten; do not reflow otherwise-untouched files (large no-op diffs bury real changes).

Project tooling wins: if `.editorconfig`, `.prettierrc`, or markdownlint configures a different policy, follow the repo's setting. Prettier `proseWrap: "preserve"` and markdownlint `MD013: false` are the compatible settings. Code blocks, tables, and frontmatter are mechanical, not prose. Commit messages and PR descriptions follow their own conventions (~72-char body wrap) and are out of scope.

## Claude-Style Workflow Intents

When user intent matches these commands, use the equivalent workflow:

- `context-prime`: load README + key project files, summarize stack, git state, and active work.
- `commit`: inspect staged/uncommitted diff, propose conventional commit message, then commit.
- `pr-create`: summarize changes, draft a complete PR body, and provide/run `gh pr create`.
- `review-pr`: fetch PR info/diff/checks and produce severity-ordered findings.
- `debug`: gather evidence, form hypotheses, identify root cause, implement minimal fix, add tests.
- `test`: generate or update tests for changed behavior and run relevant suite.
- `dependencies`: check outdated/vulnerable deps, classify risk, and update safely.
- `security-audit`: scan for credential leaks, injection risk, authz gaps, and dependency CVEs.
- `feature-spec`: produce a structured spec with stories, acceptance criteria, edge cases, and scope.
- `pipeline`: run PM -> Architect -> Implementer -> QA stages with user checkpoints.

## Pipeline Rules

- Stage 1 (PM): create spec with clear acceptance criteria.
- Stage 2 (Architect): validate design and write ADR-level decisions.
- Stage 3 (Implementer): build exactly to spec/ADR and add tests.
- Stage 4 (QA): verify requirements, run checks, and decide `DONE` vs `NEEDS_WORK`.
- Pause between stages for user review before proceeding.
