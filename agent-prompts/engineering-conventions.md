# Shared engineering conventions

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

## Forge CLIs: subcommands over raw API

Prefer purpose-built `gh` and `glab` subcommands over `gh api` / `glab api`.
Reach for `api` only when the higher-level CLI does not expose the required operation or data; when that limitation is not obvious, state it briefly.
Before using `api` for a common operation -- viewing diffs, commits, checks, pipelines, discussions, or metadata -- check the relevant `gh` or `glab` help first.
Do not preserve an API workaround merely because an older CLI version lacked the capability: current `glab` supports `mr diff` and `mr view --comments`, `--resolved`, and `--unresolved`, so those no longer justify `glab api`.

## Glob expansion and argument limits

The shell expands a glob before the command runs: `cmd **/*.ts` reaches `cmd` as the literal path of every match, not as a pattern.
The kernel caps arguments plus environment together at roughly 2 MB per `execve`, so a match list in the tens of thousands fails with `E2BIG` ("argument list too long").

Do not let a glob's match count scale with repository contents.
Globbing top-level directories (`*/`) is fine -- it matches a handful of entries.
A recursive glob (`**`, or nested `*/*/*`) is not, when anchored at a workspace root holding several repositories, or at a worktree directory where every worktree is a full checkout and each one added grows the match list.

For bulk operations over many files, stream instead of expanding:

```bash
rg --files -g '*.ts' | xargs -r some-command
fd -e ts -X some-command
```

Both chunk their arguments and have no size ceiling, so they keep working as the tree grows.

Searching is unrestricted at any scope: `rg` streams results rather than building an argument list, and it honors `.gitignore` plus `.ignore`. A directory holding several checkouts is not itself a repository, so no `.gitignore` governs it; an `.ignore` file at that level is what keeps a search from descending into every checkout below it.

## Comments: prefer self-explanatory code

Reach for a comment only when the code cannot explain itself, and match the comment density of neighboring files in the same role -- a file far chattier or barer than its peers is a smell in either direction.
Before writing or keeping one, try in order:

1. **Fold it into a name.** Rename the symbol, or extract a named helper or constant, until the comment is redundant (`codeOf` -> `mappedErrorCodeFor`).
2. **Fold it into the type or a validation.** A precise type, enum, or narrowed signature often says what the comment was compensating for; an assertion or schema check states the invariant the comment only warned about.
3. **Fold it into structure.** Reshape control flow (early return, extracted branch, reordered steps) or pin the behavior with a test, until the comment is redundant.
4. **Delete it** if the name, signature, or body already carries the content.

Keep a comment only when it explains *why*, not *what*: non-obvious rationale or a rejected alternative; external constraints and gotchas (ordering/lifecycle, load-order, framework semantics not visible locally, concurrency hazards); a workaround and its reason; a pointer to the ticket, spec, or upstream issue that motivates the code.

Drop as noise: restatements of the name, signature, or next line; narration of self-descriptive code or of the edit that produced it; prose gone stale against the code; redundant doc blocks on helpers whose name and body are already clear; section-divider banners; commented-out code.

Before handoff, sweep the comments in your diff: remove any whose meaning is now expressed through names, types, validation, structure, control flow, or tests.
Tradeoff analysis belongs in the handoff report and review discussion, where the reader can weigh it; encode it as a source comment only when it records a durable, non-obvious constraint that code and tests cannot express.

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
4. **PR, MR, issue, and comment bodies on GitHub and GitLab do NOT wrap.** Both forges render them as GFM with hardbreaks enabled, so every newline becomes a `<br>` and a 72-column source displays as a narrow ragged column. Let paragraph lines run long, or use one sentence per line; separate paragraphs with blank lines. This is deliberately the opposite of the commit-message rule above, and applies only to text destined for the forge web UI -- `.md` files rendered from the repo do reflow and follow the default.

When in doubt, match the surrounding file's existing style rather than introducing a third pattern.
