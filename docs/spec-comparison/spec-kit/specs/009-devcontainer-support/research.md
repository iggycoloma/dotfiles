# Research: Devcontainer Support

## Q1: Why was workspace-local state persistence rejected?

**Decision**: State must NOT live inside the project directory. Use
volume / Codespaces persistedshare / ephemeral only.

**Options considered**:

1. **Volume mount only**. Cleanest separation. But requires every user
   to add a `mounts` line to their `devcontainer.json`. Fails open for
   users who don't read README.
2. **Workspace-local: `<project>/.dotfiles-state/`** (gitignored). No
   user configuration required; Just Works. **Rejected** -- see below.
3. **Codespaces persistedshare + ephemeral fallback** (chosen). Auto-
   detects Codespaces; falls back to ephemeral on local without
   volume. Layers on top of the volume tier.

**Why workspace-local was rejected**:

- **Backup tooling**: `tar -cf project.tar.gz <project>/` would
  capture auth tokens. Users who back up their work directory would
  inadvertently leak credentials.
- **Archive uploads**: `git stash`, `git archive`, "share this folder
  with me" all risk including the state dir.
- **Docker COPY**: Multi-stage Dockerfiles that `COPY . /app/` would
  bake credentials into image layers. Even with `.dockerignore` listing
  the path, one missed entry = baked credential.
- **Workspace scanners**: IDE indexers (VS Code search, ripgrep
  servers, language servers) would index the state dir. Search history
  could surface tokens.
- **Blast radius**: Even with `.gitignore` AND `.git/info/exclude` AND
  `.dockerignore`, a single tool that bypasses these (cp, rsync, scp,
  archive plugins) leaks. The cost of accidental exposure is catastrophic
  (root access to GitHub, AWS, etc.).

The full analysis lived in `docs/future-workspace-local-state.md` but
was deleted as part of the agentic harness extraction. The decision
is preserved here and in the
`extract-agentic-harness` archived OpenSpec change.

**Trade-off**: Local devcontainers without volume mount fall back to
ephemeral state -- credentials lost on rebuild. Acceptable: re-auth
once vs. credential exfiltration risk.

## Q2: Why force-copy AI tool config on every container start (instead of symlinking)?

**Decision**: Devcontainers stomp-copy; hosts symlink. Same answer as
006-claude-code-config Q2 -- repeated here for the devcontainer-
support context.

**Rationale**:

- Atomic file writes (Write tool, `mv tmp file`) replace symlinks
  with regular files. Tools that use atomic writes (every modern
  config-rewrite tool) silently break the symlink.
- Containers are ephemeral; users expect a fresh state on rebuild.
  Symlinking from the (volume-backed) repo wouldn't even be possible
  if the repo is checked out at `/workspaces/.dotfiles` and config
  needs to live at `~/.claude/settings.json`.
- Stomp-copy guarantees the container runs the dotfiles' current
  version of every config file. No drift.

**Trade-off**: Local edits to `~/.claude/settings.json` inside a
devcontainer are lost on rebuild. Mitigated by encouraging users to
make config changes in the dotfiles repo (which is mounted into
`/workspaces/.dotfiles`) and re-run install.

## Q3: Why volume-back the AI tool config dirs (not just the state file)?

**Decision**: Use directory symlinks for `~/.claude`, `~/.codex`,
`~/.copilot`, `~/.config/gh` -- each pointing at a state-backed
directory.

**Options considered**:

1. **Per-file symlinks for credentials**. Symlink only
   `~/.claude/.credentials.json`, `~/.config/gh/hosts.yml`, etc. Keep
   the rest in the container. **Problem**: We don't know in advance
   which files Claude Code will write (config.json, history.json,
   sessions/, etc.). Per-file symlinks miss new files.
2. **Whole-directory symlink for the parent** (chosen). Symlink
   `~/.claude -> ~/.dotfiles-state/claude/`. Every file Claude writes
   lands on the volume automatically.
3. **Bind mount inside the container**. Cleanest from the
   filesystem POV but requires container runtime support and tooling
   we don't control (VS Code's devcontainer feature set).

**Rationale**: Directory symlinks are robust to upstream tool
changes -- if Claude adds a new file under `~/.claude/`, it lands on
the volume by default. Per-file symlinks would silently miss new
files.

**Trade-off**: The whole `~/.claude/` lives on the volume, not just
the credentials. This means `~/.claude/CLAUDE.md` (deployed by
dotfiles, refreshed each boot) is also on the volume -- but the boot
refresh stomps it back to the current dotfiles version each time, so
the volume copy stays in sync.

## Q4: Why prefer ed25519 SSH keys for signing detection?

(Cross-reference: this question lives in 001-install but the rationale
is shared here because devcontainers inherit SSH keys via VS Code
agent forwarding.)

**Decision**: Prefer ed25519 over RSA when both are available on the
SSH agent.

**Rationale**: ed25519 is faster, smaller, and considered more
modern. RSA keys < 4096 bits are increasingly rejected by hosts. The
preference order is `ssh-ed25519` from agent > `~/.ssh/id_ed25519.pub` >
`~/.ssh/id_rsa.pub`.
