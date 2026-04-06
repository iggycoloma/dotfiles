# Dotfiles Repository -- Agent Instructions

Shared instructions for all AI coding tools (Claude Code, Codex, Copilot, Cursor, Windsurf, Amp, Devin).
Tool-specific overrides live in `claude-code/CLAUDE.md` and `codex/AGENTS.md`.

## Guardrails

- No emojis in code, docs, or commit messages
- Use conventional commits; no AI attribution or Co-Authored-By lines
- Never read .env, credentials, secrets, .pem, .key files
- Never access credential directories: ~/.ssh, ~/.aws, ~/.gnupg, ~/.azure, ~/.config/gcloud, ~/.config/gh, ~/.docker, ~/.kube, ~/.config/heroku, ~/.config/doctl, ~/.gradle, ~/.m2, ~/.minikube, ~/.cargo, ~/.gem, ~/.composer, ~/.stripe, ~/.dotfiles-state
- Never access credential files: ~/.npmrc, ~/.pypirc, ~/.netrc, ~/.git-credentials, ~/.pgpass, ~/.my.cnf, ~/.mongorc.js, *.tfvars, *.ppk, *.jks, *.keystore, *.pfx, *.p12
- Deny path traversal patterns (`../`) unless the user explicitly asks and confirms

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

## Shell Script Quality

- Run `shellcheck` on shell scripts before committing
- Fix all shellcheck warnings unless there's a documented reason to suppress

## Structural Code Search (ast-grep)

When searching for code patterns like "all function calls to X" or "all imports of Y",
prefer `sg` over `rg`. Examples:

- `sg --pattern 'console.log($$$)' --lang js` -- find all console.log calls
- `sg --pattern 'import $_ from "react"' --lang tsx` -- find React imports
- Use `sg --help` to learn more patterns

## File Watching

- Use `watchexec` for auto-test/rebuild loops when iterating on changes
- Example: `watchexec -e py -- pytest tests/`

## Installation Toggles

These environment variables control what `install.sh` installs:

| Variable | Effect |
|----------|--------|
| `DOTFILES_NO_AI_TOOLS=1` | Skip agentic CLIs, ast-grep, difftastic, and AI config |
| `DOTFILES_NO_ATUIN=1` | Skip atuin and bash-preexec |
| `DOTFILES_NO_GIT_HOOKS=1` | Skip global git hooks |
| `DOTFILES_NO_STATE_PERSISTENCE=1` | Skip state persistence tier detection |

CLI tools in the Preferred CLI Tools table may not be available if toggles are active.

## Working Style

- Keep changes minimal and focused; do not refactor unrelated code
- Run relevant tests/lint after changes when practical and report what was run
- If asked for a review, prioritize bugs/regressions/security issues first, then style
