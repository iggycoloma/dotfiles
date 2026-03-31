# Global Claude Code Instructions

## Guardrails

- No emojis in code, docs, or commit messages
- Use conventional commits; no AI attribution or Co-Authored-By lines
- Never read .env, credentials, secrets, .pem, .key files
- Never access credential directories: ~/.ssh, ~/.aws, ~/.gnupg, ~/.azure, ~/.config/gcloud, ~/.config/gh, ~/.docker, ~/.kube, ~/.config/heroku, ~/.config/doctl, ~/.gradle, ~/.m2, ~/.minikube, ~/.cargo, ~/.gem, ~/.composer, ~/.stripe
- Never access credential files: ~/.npmrc, ~/.pypirc, ~/.netrc, ~/.git-credentials, ~/.pgpass, ~/.my.cnf, ~/.mongorc.js, *.tfvars, *.ppk, *.jks, *.keystore

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
