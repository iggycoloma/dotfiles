# install -- Change Delta (extract-agentic-harness, ARCHIVED)

> Adds the `--with-agentic` / `--without-agentic` CLI flags and the
> opt-in gating logic that the new `agentic-harness` capability
> needs.

## ADDED Requirements

### CLI flags

- `install.sh` MUST accept `--with-agentic` (alias for
  `DOTFILES_INSTALL_AGENTIC=1`).
- `install.sh` MUST accept `--without-agentic` (alias for
  `DOTFILES_INSTALL_AGENTIC=0`).
- `install.sh --help` MUST document both flags.
- The installer MUST tolerate unknown positional arguments (older CI
  callers may pass env vars positionally).

### Opt-in gating

- The installer MUST NOT deploy `~/.agentic/` unless
  `DOTFILES_INSTALL_AGENTIC=1` is set.
- The opt-in state MUST be logged at install time
  (`Agentic Harness: enabled` or `Agentic Harness: disabled`).

## MODIFIED Requirements

### Tiny CLI surface

**Previous behavior**: `install.sh` accepted only `-h`/`--help`. No
behavior-controlling flags.

**New behavior**: `install.sh` accepts `--with-agentic`,
`--without-agentic`, `-h`, `--help`, and tolerates unknown args.

The "tiny CLI surface" requirement is updated -- it is no longer
"only `-h` and `--help`". The CLI surface is now "small but extant"
and the help text is the source of truth.

### `_setup_claude_code` no longer deploys agentic payload

**Previous behavior**: `_setup_claude_code` deployed:
`settings.json`, `CLAUDE.md`, `statusline.sh`, `hooks/`, `agents/`,
`commands/`, AND `templates/`, `scripts/`, `devcontainer-rubric.json`,
`egress-allowlist.txt`, `bootstrap/`.

**New behavior**: `_setup_claude_code` deploys ONLY:
`settings.json`, `CLAUDE.md`, `statusline.sh`, `hooks/`, `agents/`,
`commands/`. The agentic payload is now `_setup_agentic`'s
responsibility.

## REMOVED Requirements

(none in `install` -- requirements changed but none were removed
outright. The agentic-payload requirements moved to
`agentic-harness` rather than disappearing.)
