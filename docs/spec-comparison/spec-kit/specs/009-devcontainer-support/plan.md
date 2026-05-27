# Implementation Plan: Devcontainer Support

**Branch**: `009-devcontainer-support` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)

## Summary

Auto-detect devcontainer / Codespaces; install AI tools as native
binaries (no Node.js); pick one of three state-persistence tiers
(volume > Codespaces persistedshare > ephemeral); wire AI tool config
dirs to volume-backed paths; force-refresh dotfiles config on every
container start. Container variant files are deployed as copies so the
dotfiles repo need not be present at runtime. Attended devcontainers
do not enforce network-layer egress -- dc-audit spec-linting is the
attended-profile defense; the prior `bootstrap/devcontainer-egress.sh`
script and its env vars have been removed. Workspace-local state was
evaluated and rejected (see research.md).

## Technical Context

| Field             | Value                                                                              |
|-------------------|------------------------------------------------------------------------------------|
| Language/Version  | Bash for installer logic                                                           |
| Dependencies      | docker (volume mounts); VS Code Remote Containers; GitHub Codespaces infrastructure |
| Storage           | `~/.dotfiles-state/` (volume / persistedshare / ephemeral)                         |
| Testing           | `tests/test-install.sh` integration; CI runs in container matrix                   |
| Target Platform   | All devcontainer-capable: Linux containers, Codespaces                            |
| Project Type      | Single Project                                                                     |
| Performance Goals | State setup overhead <2s; per-boot config refresh <5s                              |
| Constraints       | Cannot mutate devcontainer.json (only logs the recommended snippet)                |
| Scale/Scope       | 3 tiers, 4 volume-backed dirs (~/.claude, ~/.codex, ~/.copilot, ~/.config/gh)      |

## Constitution Check

| Article                            | Status | Notes                                                                       |
|------------------------------------|--------|------------------------------------------------------------------------------|
| I. Developer-Specific              | PASS   | All persistence is for developer-tool state, not project tooling.            |
| II. Defense-in-Depth Security      | PASS   | Workspace-local state explicitly rejected (research.md Q1) due to credential exposure risk. |
| III. Cross-Platform Parity         | PASS   | Devcontainers tested on Linux container; Codespaces auto-detected.           |
| IV. Idempotent and Reversible      | PASS   | Tier detection is pure; setup is idempotent.                                 |
| V. Opt-In for High-Risk Surface    | PASS   | `DOTFILES_NO_STATE_PERSISTENCE=1` opt-out for users who want pure ephemeral. |

## Project Structure

```
bootstrap/
|-- detect.sh           (detect_state_tier, is_devcontainer, is_minimal_install alias)
+-- symlinks.sh         (setup_state_persistence, setup_volume_dir,
                         _deploy_variant_file for host vs container pairs)
.devcontainer/
|-- example/            (reference devcontainer.json with volume mount)
+-- unattended/         (delegated to 010-unattended-harness)
```

Notably absent: `bootstrap/devcontainer-egress.sh`. The attended
devcontainer egress script was removed (see PR #53); dc-audit
spec-linting under `make lint` is the new attended-profile defense.

### Structure Decision

Single Project. State-persistence logic is split across `detect.sh`
(pure detection) and `symlinks.sh` (side-effecting setup) following
the project pattern of detect/setup separation.

## Complexity Tracking

| Violation                                                                | Why Needed                                                                                                                                              | Simpler Alternative Rejected Because                                                                                                                                          |
|--------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Three persistence tiers (volume / codespaces / ephemeral)                | Different deployment targets have different persistence mechanisms; one-size-fits-all loses Codespaces auto-magic OR forces volume-mount config on local users. | Single ephemeral tier: state loss on every rebuild kills credential auto-restore. Single volume tier: requires devcontainer.json change for every project. Single Codespaces tier: doesn't work locally at all. |
| Volume-backed dirs use directory symlinks (not file symlinks)            | Atomic file writes (Write tool, `mv`, `cp -f`) replace file symlinks with regular files, breaking the volume backing.                                   | File symlinks: silent breakage on first atomic write to settings.json or credentials. We'd lose state without warning.                                                            |
