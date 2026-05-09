# Tasks: Packages

## Phase 1: Setup

- [X] T001 Create `bootstrap/packages.sh` skeleton with `install_packages`
       entrypoint and per-OS dispatch.
- [X] T002 [P] Add `tests/test-packages.sh` with helpers
       (`assert_tool_installed`, `assert_tool_version_at_least`).

## Phase 2: Foundational

- [X] T003 Helper: `_install_from_github_release <repo> <asset_pattern>`
       -- downloads, sha256-verifies, extracts to `~/.local/bin/`.
- [X] T004 Helper: `_install_via_brew <pkg>` -- guarded by `command -v brew`.
- [X] T005 Helper: `_install_via_apt <pkg>` -- guarded by `command -v
       apt-get`.
- [X] T006 Helper: `_install_via_apk <pkg>` -- guarded by `command -v apk`.

## Phase 3: User Story 1 - Linux: GitHub releases (Priority: P1)

### Tests for User Story 1

- [X] T007 [P] [US1] Test: starship installs from GitHub release on
       Ubuntu, version >= 1.0.
- [X] T008 [P] [US1] Test: SHA-256 verification rejects tampered
       download.
- [X] T009 [P] [US1] Test: re-install of current starship version is
       no-op.

### Implementation for User Story 1

- [X] T010 [US1] Add starship installer function (GitHub API for latest
       version + asset URL).
- [X] T011 [US1] Add zoxide, eza, sd, scc, yq, watchexec, ast-grep,
       difftastic via the same `_install_from_github_release` helper.
- [X] T012 [US1] Add gitleaks, dust, duf, procs, hyperfine, yazi, bat
       per their preferred channel (some apt, some release).

## Phase 4: User Story 2 - macOS: brew only (Priority: P1)

### Tests for User Story 2

- [X] T013 [P] [US2] Test on macOS runner: zero `curl ...
       github.com/.../releases` calls during install.
- [X] T014 [P] [US2] Test: every tool resolves on PATH after install.

### Implementation for User Story 2

- [X] T015 [US2] Wrap every per-tool installer with `is macOS -> brew;
       else -> Linux path` dispatch.

## Phase 5: User Story 3 - AI tools opt-out (Priority: P2)

### Tests for User Story 3

- [X] T016 [P] [US3] Test: `DOTFILES_NO_AI_TOOLS=1` -> no claude/codex/
       ast-grep/difftastic on PATH.

### Implementation for User Story 3

- [X] T017 [US3] Wrap AI tool installers with `[[ "${DOTFILES_NO_AI_TOOLS:-}"
       != "1" ]]` guard.

## Phase 6: Polish

- [X] T018 Add `_check_already_installed` short-circuit at the top of each
       per-tool function for idempotency.
- [X] T019 Run `make lint` -- expect 0 warnings.
- [X] T020 Run `make test-packages` -- expect green on every matrix cell.

## Dependencies & Execution Order

Phase 1 -> Phase 2 -> Phase 3 + Phase 4 (parallel possible since US1 and
US2 touch different code paths) -> Phase 5 -> Phase 6.

## Parallel Example

T010 / T011 / T012 in Phase 3 can be authored in parallel (each adds a
distinct per-tool function); they all touch `bootstrap/packages.sh` so
final integration is sequential.

## Implementation Strategy

MVP is one tool through each channel (e.g. starship via release, jq via
apt, ripgrep via brew on macOS). Then add the rest per pattern.
