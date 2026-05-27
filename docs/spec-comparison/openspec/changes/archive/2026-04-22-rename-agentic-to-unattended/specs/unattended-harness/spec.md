# unattended-harness -- Change Delta (rename-agentic-to-unattended)

## ADDED Requirements

Every requirement previously held by `agentic-harness` is re-added here under the new capability name, with paths/flags updated.

### Opt-in deployment

- The unattended harness MUST NOT deploy by default.
  The installer MUST deploy `~/.unattended/` only when `DOTFILES_INSTALL_UNATTENDED=1` is set (either via `--with-unattended` flag or directly in env).
- The unattended devcontainer profile MUST set `DOTFILES_INSTALL_UNATTENDED=1` in `containerEnv`.
- `--without-unattended` MUST set `DOTFILES_INSTALL_UNATTENDED=0`.

### Layout under ~/.unattended/

- The deployed `~/.unattended/` MUST contain `scripts/`, `templates/`, `bootstrap/`, `devcontainer-rubric.json`, `egress-allowlist.txt`, `lib/logging.sh`.
- Every script in `scripts/` and `bootstrap/` MUST be executable.

### ralph.sh, dc-audit.sh, unattended profile, mitmproxy egress,
unattended deps

(restated unchanged from the previous capability; only the in-spec paths -- `unattended/devcontainer-rubric.json`, `unattended/egress-allowlist.txt`, `unattended/bootstrap/...` --differ from the pre-rename state)

### Scenarios

All scenarios from the previous capability are re-added with `agentic` replaced by `unattended` in deploy paths, flag names, and env vars.

### Non-Behavior

All Non-Behavior entries from the previous capability are re-added, with paths updated.

## Rationale

This is the paired ADDED side of the rename.
The canonical spec at `openspec/specs/unattended-harness/spec.md` is the merged result; this delta shows the rename as a reviewable artifact.

The rename is purely nominal in OpenSpec terms: no behavior change, no requirement loosening, no scope expansion.
Future changes to this capability (Tier 2, Tier 3) live in their own change folders.

## Reviewer checklist

- [x] Every requirement in the REMOVED sibling appears here.
- [x] No requirement was strengthened, weakened, or scope-shifted in the rename.
  Path/flag substitution only.
- [x] The capability heading uses the new name.
- [x] All deploy/flag/env-var references use the new vocabulary.
