# agentic-harness -- Change Delta (rename-agentic-to-unattended)

## REMOVED Requirements

Every requirement previously held by `agentic-harness` is removed.
The capability ceases to exist under this name.
The same requirements reappear under `unattended-harness` (see paired delta in this archive).

- All requirements under "Opt-in deployment" (3 entries: `DOTFILES_INSTALL_AGENTIC=1`, containerEnv default in unattended profile, explicit `--without-agentic` opt-out).
- All requirements under "Layout under `~/.agentic/`" (deploy path and permissions).
- All requirements under "ralph.sh: autonomous loop" (5 entries: PRD-driven loop, iteration structure, halt conditions, exit-code set, ralph-parallel.sh).
- All requirements under "dc-audit.sh: devcontainer linter" (4 entries: rubric path `agentic/devcontainer-rubric.json`, profile flags, `--fix` semantics, `--strict --json` CI mode).
- All requirements under "Unattended devcontainer profile" (5 entries referencing `containerEnv`, `postCreateCommand` invocations, mount prohibitions, `GH_TOKEN` posture).
- All requirements under "Egress allowlist (mitmproxy)" (3 entries referencing `agentic/egress-allowlist.txt`).
- All requirements under "Unattended deps" (2 entries: `unattended-deps.sh` package set, `unattended-entrypoint.sh` scope check).
- All scenarios referencing `~/.agentic/`, `--with-agentic`, or `agentic/egress-allowlist.txt`.
- All Non-Behavior entries referencing the old paths.

## Rationale

The rename matches the repo-level rename (PR #53): `agentic/` -> `unattended/`, `~/.agentic/` -> `~/.unattended/`, `--with-agentic` -> `--with-unattended`.
The new vocabulary is explicit: "agentic" describes the broad interactive AI toolset; the unattended harness is specifically the opt-in autonomous-loop stack.
The capability name follows the repo.

## Reviewer note

This delta should pair line-for-line with the ADDED section of `specs/unattended-harness/spec.md` in this same archive entry.
If a requirement is REMOVED here without an ADDED counterpart, that is a silent capability loss and must be flagged.
