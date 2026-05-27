# Tasks: Install

## Phase 1: Setup (Shared Infrastructure)

- [X] T001 Create `bootstrap/logging.sh` with `log_info`, `log_section`,
       `log_success`, `log_warn`, `log_error`. Color-aware (no ANSI when
       `! -t 1`).
- [X] T002 [P] Create `Makefile` with `lint`, `test`, `test-unit`,
       `test-packages`, `test-integration`, `test-consistency`, `test-policy`,
       `test-ralph`, `test-dc-audit` targets.
- [X] T003 [P] Add `tests/unit-tests.sh` skeleton with bash assertion helpers.

## Phase 2: Foundational (Blocking Prerequisites)

- [X] T004 Implement `bootstrap/detect.sh::detect_environment` (Codespaces /
       devcontainer / remote / local).
- [X] T005 Implement `bootstrap/detect.sh::detect_os` (macos / debian /
       alpine / linux / unknown via OSTYPE + /etc/os-release).
- [X] T006 Implement `bootstrap/detect.sh::detect_package_manager` (brew /
       apt / apk / none).
- [X] T007 Implement `bootstrap/detect.sh::is_minimal_install`,
       `is_devcontainer`, `is_dotfiles_workspace` predicates.
- [X] T008 Implement `bootstrap/detect.sh::detect_state_tier` (volume /
       codespaces / ephemeral; pure detection, no side effects).
- [X] T009 Export all detection functions so subscripts can use them.

## Phase 3: User Story 1 - Fresh devcontainer install (Priority: P1)

### Tests for User Story 1

- [X] T010 [P] [US1] `tests/test-install.sh` -- spin a fresh container,
       run `./install.sh`, assert `~/.bashrc` symlink present and points to
       `$DOTFILES_DIR/shell/.bashrc`.
- [X] T011 [P] [US1] `tests/test-install.sh` -- assert
       `~/.config/git/config` contains `[include]` of dotfiles gitconfig.
- [X] T012 [P] [US1] `tests/test-install.sh` -- assert `~/.claude/`,
       `~/.codex/`, `~/.copilot/` populated.
- [X] T013 [P] [US1] `tests/test-install.sh` -- assert
       `dotfiles-doctor` reports 0 failures.

### Implementation for User Story 1

- [X] T014 [US1] `install.sh` entrypoint: `set -u`, parse flags, source
       `bootstrap/logging.sh`.
- [X] T015 [US1] `install.sh` env detection section: call detect_*
       functions, log results.
- [X] T016 [US1] `install.sh` packages section: source and call
       `install_packages` (defined in 002-packages).
- [X] T017 [US1] `install.sh` symlinks section: source and call
       `create_symlinks` (defined here).
- [X] T018 [US1] `bootstrap/symlinks.sh::backup_if_exists` -- back up
       existing real file/directory to `~/.dotfiles_backup_<timestamp>/`.
- [X] T019 [US1] `bootstrap/symlinks.sh::create_symlink` -- create symlink
       with backup.
- [X] T020 [US1] `bootstrap/symlinks.sh::stomp_configs` -- force-copy
       files/dirs in devcontainers.
- [X] T021 [US1] `bootstrap/symlinks.sh::_deploy_configs` -- branch on
       `is_devcontainer` to either symlink or stomp.
- [X] T022 [US1] `bootstrap/symlinks.sh::_ensure_git_include` -- prepend
       `[include]` to `~/.config/git/config` (idempotent, migration-aware).
- [X] T023 [US1] `bootstrap/symlinks.sh::_setup_claude_code`,
       `_setup_codex`, `_setup_copilot` -- per-AI-tool wiring.

## Phase 4: User Story 2 - Re-run is a no-op (Priority: P1)

### Tests for User Story 2

- [X] T024 [P] [US2] Run `./install.sh` twice in `tests/test-install.sh`,
       assert exit 0 both times and no duplicate `[include]` entries.
- [X] T025 [P] [US2] Assert no new `~/.dotfiles_backup_*` directory is
       created on the second run when nothing changed.

### Implementation for User Story 2

- [X] T026 [US2] `_ensure_git_include` -- detect existing include via
       `grep -qF` and skip if present.
- [X] T027 [US2] `backup_if_exists` -- create backup directory only when
       actually backing something up (lazy mkdir).

## Phase 5: User Story 3 - Opt-in to unattended harness (Priority: P2)

### Tests for User Story 3

- [X] T028 [P] [US3] `tests/test-ralph.sh` -- after
       `./install.sh --with-unattended`, assert `~/.unattended/scripts/ralph.sh`
       exists and is executable.
- [X] T029 [P] [US3] Assert `~/.unattended/lib/logging.sh` is a copy of
       `bootstrap/logging.sh`.

### Implementation for User Story 3

- [X] T030 [US3] `install.sh` flag parser: handle `--with-unattended` /
       `--without-unattended` / `-h`, tolerate unknown args.
- [X] T031 [US3] `bootstrap/symlinks.sh::_setup_unattended` -- deploy
       `~/.unattended/`, vendor logging.sh, chmod scripts/bootstrap.
- [X] T031a [US3] `bootstrap/symlinks.sh::_deploy_variant_file` -- deploy
       host vs container variant pairs (`settings.json` vs `settings.container.json`;
       `config.toml` vs `config.container.toml`). Symlinks the host variant on
       hosts; copies the container variant in devcontainers so the dotfiles
       repo need not be present at runtime.
- [X] T031b [US3] `bootstrap/packages.sh` -- on Linux hosts, install
       `bubblewrap` and `socat` as a paired prerequisite (skipped inside
       devcontainers). The Claude Code host sandbox needs both: `bwrap`
       unshares the network namespace, `socat` bridges it to the egress proxy.

## Phase 6: User Story 4 - SSH signing auto-detection (Priority: P2)

### Tests for User Story 4

- [X] T032 [P] [US4] Mock `ssh-add -L` to return an ed25519 key; run
       installer; assert `git config user.signingkey` returns
       `key::<that key>`.
- [X] T033 [P] [US4] Run installer with no SSH key available; assert
       installer exits 0 and does not set `commit.gpgsign`.
- [X] T034 [P] [US4] Assert `~/.config/git/allowed_signers` is created
       on the success path.

### Implementation for User Story 4

- [X] T035 [US4] `install.sh` SSH signing section: try `ssh-add -L`
       (prefer ed25519), then `~/.ssh/id_ed25519.pub`, then `~/.ssh/id_rsa.pub`.
- [X] T036 [US4] Set `user.signingkey`, `commit.gpgsign=true` only on
       success.
- [X] T037 [US4] Create `allowed_signers` from key + email; idempotent
       (skip if line already present).
- [X] T038 [US4] Honor `DOTFILES_NO_SSH_SIGNING=1` opt-out.

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T039 Add `dotfiles-doctor` shell function (delegated to 012-diagnostics).
- [X] T040 Add `--help` text covering flags + opt-out env vars.
- [X] T041 Document install path in `README.md`.
- [X] T042 Run `make lint` -- expect 0 warnings.
- [X] T043 Run `make test` -- expect all 7 suites pass on every matrix cell.

## Dependencies & Execution Order

### Phase Dependencies

- Phase 1 (Setup) blocks everything.
- Phase 2 (Foundational) blocks Phases 3-6.
- Phases 3 and 4 (P1) MUST complete before Phases 5 and 6 (P2).
- Phase 7 (Polish) runs last.

### Within-Phase Parallelism

- Tests in each phase (T010-T013, T024-T025, T028-T029, T032-T034) are all
  `[P]` -- they touch disjoint test cases in `tests/test-install.sh`.
- Implementation tasks within a phase are mostly sequential (they modify
  the same source files: `install.sh`, `bootstrap/symlinks.sh`).

### Parallel Opportunities

- T002, T003 in Phase 1 can run with T001.
- All `[P]`-tagged test tasks within a User Story can run together.

## Parallel Example: User Story 1 tests

```
# All four tests can be authored simultaneously by different agents,
# then run by the test harness in parallel:
T010 -- bashrc symlink
T011 -- git include
T012 -- AI tool dirs
T013 -- doctor green
```

## Implementation Strategy

- **MVP** is User Story 1: a fresh install that works on Codespaces. Ship
  that before Stories 2-4.
- **Incremental delivery**: ship 1 -> 2 -> 3 -> 4. Each story is independently
  testable in CI.
- **Coordination**: phase markers in commit messages
  (`feat(install): <story> -- <task>`) make the story / task mapping
  obvious in `git log`.
