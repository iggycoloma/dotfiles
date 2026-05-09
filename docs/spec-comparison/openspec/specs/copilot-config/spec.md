# copilot-config

## Overview

Global Copilot CLI configuration deployed to `~/.copilot/`. Single
`copilot-instructions.md` aligning Copilot's behavior with the rest of the
agentic coding tool fleet (no emoji, conventional commits, credential deny
lists, preferred CLI tools). Minimal surface intentionally: Copilot's hook
and skill systems are less mature, so the dotfiles ship instructions only.

## Requirements

### Deployment

- The installer MUST deploy `copilot-instructions.md` and `hooks.json`
  from `<DOTFILES_DIR>/copilot/` into `~/.copilot/`.
- In devcontainers, the installer MUST force-copy on every boot.
- On hosts, the installer MUST deploy via symlink so live edits in the
  repo propagate to `~/.copilot/`.
- The installer MUST honor `DOTFILES_NO_AI_TOOLS=1` and skip Copilot
  config deployment entirely when set.

### copilot-instructions.md content

- The deployed file MUST list the same credential deny patterns as
  Claude Code's CLAUDE.md and Codex's AGENTS.md (~50 patterns covering
  files, directories, and file extensions).
- The deployed file MUST list the same preferred CLI tools (rg, sg, fd,
  difft, sd, bat, scc, yq).
- The deployed file MUST forbid path traversal (`../`) without explicit
  user confirmation.
- The deployed file MUST forbid decorative emoji in code, docs, or
  commits.
- The deployed file MUST forbid AI attribution and `Co-Authored-By` in
  commits.
- The deployed file MUST forbid installing new MCP servers without
  explicit user request.

### Treatment as credential-adjacent

- The credential deny lists in Claude Code, Codex, and the global git
  hooks MUST include `~/.copilot` as a credential directory (since it
  may contain Copilot session tokens).

## Scenarios

### Scenario: Devcontainer rebuild refreshes instructions

GIVEN a devcontainer with `~/.copilot/copilot-instructions.md` from a
previous build
WHEN the container rebuilds and `./install.sh` runs
THEN the existing file is replaced (stomped) with the current
`<DOTFILES_DIR>/copilot/copilot-instructions.md`
AND any local edits the user made in the previous container are lost
(intentional -- containers are ephemeral).

### Scenario: Host symlink survives source edits

GIVEN a host install where `~/.copilot/copilot-instructions.md` is a symlink
WHEN the user edits `<DOTFILES_DIR>/copilot/copilot-instructions.md`
THEN the change is immediately visible to Copilot's next invocation
AND no re-install is required.

### Scenario: AI tools opt-out skips Copilot

GIVEN `DOTFILES_NO_AI_TOOLS=1` is set
WHEN `./install.sh` runs
THEN no `~/.copilot/` files are deployed
AND the installer logs that AI tool setup is skipped.

## Non-Behavior

- The Copilot config does NOT install Copilot CLI itself.
- The Copilot config does NOT ship slash commands or skills (Copilot
  CLI's command surface is upstream).
- The Copilot config does NOT include hooks beyond the minimal
  `hooks.json` upstream Copilot expects.
- The Copilot config does NOT have a status line or notification
  integration.
- The Copilot config does NOT track or persist Copilot session state in
  this repo (state lives in `~/.copilot/` proper, mounted via the state
  persistence tier in devcontainers).
