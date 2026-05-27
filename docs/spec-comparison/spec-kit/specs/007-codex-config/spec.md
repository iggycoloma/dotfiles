# Feature Specification: Codex CLI Configuration

**Branch**: `007-codex-config` | **Date**: 2026-04-01 | **Status**: Implemented

## User Scenarios & Testing

### User Story 1 - Claude-parity workflows in Codex (Priority: P1)

A developer who knows Claude Code's command set (commit, pr-create,
review-pr, debug, pipeline) wants the same intents in Codex CLI.

**Independent Test**: Invoke Codex with intent matching "commit"; assert
the claude-parity skill is selected and proposes a conv-commit message.

**Acceptance Scenarios**:
```
GIVEN the user types a commit-related intent in Codex
WHEN the claude-parity skill resolves
THEN Codex inspects staged/unstaged diff
  AND proposes a conventional commit message
  AND runs git commit only after user confirms
```

### User Story 2 - Idle Pushover notification (Priority: P2)

A developer running long Codex tasks wants notifications when Codex
becomes idle.

**Acceptance Scenarios**:
```
GIVEN PUSHOVER_TOKEN and PUSHOVER_USER are set
WHEN Codex finishes a step and waits for input
THEN ~/.codex/hooks/notify.sh fires
  AND a Pushover notification reaches the user within 5s
```

### User Story 3 - Local config.toml preserved (Priority: P2)

Codex stores per-machine trust state in `~/.codex/config.toml`. The
installer must never clobber this on host re-installs. This applies to
the host variant only; inside devcontainers the container variant is
re-stomped on every install so the in-container Codex always reflects
the dotfiles repo.

**Acceptance Scenarios**:
```
GIVEN the user has manually edited ~/.codex/config.toml on a host
WHEN ./install.sh runs
THEN the installer logs "Skipping ~/.codex/config.toml (preserving local Codex settings)"
  AND the file is byte-for-byte unchanged
```

### User Story 4 - Host vs container sandbox mode (Priority: P1)

A developer running Codex on a host wants OS-level sandboxing
(`workspace-write`); inside a devcontainer the container is already the
isolation boundary, so the in-container variant runs with
`danger-full-access` to avoid redundant friction.

**Independent Test**: Inspect `~/.codex/config.toml` after `./install.sh`
on each platform: host MUST contain `sandbox_mode = "workspace-write"`;
devcontainer MUST contain `sandbox_mode = "danger-full-access"`.
`approval_policy = "on-request"` MUST be identical in both.

**Acceptance Scenarios**:
```
GIVEN the installer runs on a host (macOS or Linux, not a devcontainer)
WHEN _setup_codex deploys the variant pair
THEN ~/.codex/config.toml is a symlink to codex/config.toml
  AND it contains sandbox_mode = "workspace-write"

GIVEN the installer runs inside a devcontainer
WHEN _setup_codex deploys the variant pair
THEN ~/.codex/config.toml is a real file (copy) of codex/config.container.toml
  AND it contains sandbox_mode = "danger-full-access"
  AND the dotfiles repo need not be present at runtime
```

### Edge Cases

- **Legacy notify-string format** in `~/.codex/config.toml`: installer
  rewrites to array form.
- **No `config.toml` exists**: installer seeds it with the notify hook
  line.
- **Whole-directory symlink at `~/.codex` (legacy)**: installer removes
  before deploying managed files.

## Requirements

### Functional Requirements

- **FR-001** Installer MUST deploy `AGENTS.md`, `hooks.json`, `hooks/`,
  per-skill subdirs of `skills/` from `codex/` to `~/.codex/`.
- **FR-002** Installer MUST migrate from a legacy whole-directory
  symlink at `~/.codex` (host installs only).
- **FR-003** Installer MUST preserve a user-edited `~/.codex/config.toml`
  on hosts. The host variant is deployed via `_deploy_variant_file` with
  `preserve_existing=1`: the first install symlinks `codex/config.toml`,
  but if a real file is already present (because the user edited it) the
  installer leaves it untouched. Inside devcontainers the container
  variant is always re-stomped (no preservation).
- **FR-004** Installer MUST seed `config.toml` with notify hook if
  missing.
- **FR-005** Installer MUST migrate legacy `notify = "bash ..."` string
  form to `notify = ["bash", "..."]` array form.
- **FR-006** Deployed `AGENTS.md` MUST list the same credential deny
  patterns as Claude Code's `CLAUDE.md`.
- **FR-007** Deployed `AGENTS.md` MUST list preferred CLI tools (rg,
  sg, fd, difft, sd, bat, scc, yq).
- **FR-008** Deployed `AGENTS.md` MUST forbid installing MCP servers
  without explicit user request.
- **FR-009** `~/.codex/skills/claude-parity/` MUST map intents to
  Claude Code workflows: context-prime, commit, pr-create, review-pr,
  debug, test, dependencies, security-audit, feature-spec, pipeline.
- **FR-010** Pipeline skill MUST replicate the 4-stage flow with user
  checkpoints.
- **FR-011** `~/.codex/hooks/notify.sh` MUST silently no-op without
  PUSHOVER_TOKEN/USER.
- **FR-012** Shell aliases `cx`, `cxe`, `cxr` MUST be defined.
- **FR-013** `codex/config.toml` (host) MUST set
  `sandbox_mode = "workspace-write"`; `codex/config.container.toml`
  (container) MUST set `sandbox_mode = "danger-full-access"`. Both MUST
  set `approval_policy = "on-request"`. The variant pair is deployed via
  `_deploy_variant_file` (host: symlink; container: copy).

### Key Entities

- **Skill**: directory of markdown files mapping intents to workflows.
- **Hook**: bash script invoked by Codex on lifecycle events
  (currently only `notify` is wired).

## Success Criteria

- **SC-001** Codex commit-intent reliably proposes a conv-commits
  message (CI test).
- **SC-002** Notify hook reaches the user's phone in < 5s (manual
  smoke test; not in CI).
- **SC-003** Local config.toml preservation: 100% of host CI runs
  with pre-existing config.toml leave it byte-identical.
- **SC-004** Cross-tool deny-list parity verified by
  `tests/test-consistency.sh`.

## Assumptions

- Codex CLI's notify-hook contract is stable.
- Users do not configure unrelated skills under
  `~/.codex/skills/claude-parity/` (we don't merge; we deploy).
- Codex's `config.toml` schema for `notify` accepts the array form
  (verified against Codex 0.x).
