# Tasks: Unattended Harness

## Phase 1: Setup

- [X] T001 Create `unattended/` directory structure (scripts/, templates/,
       bootstrap/, hooks/).
- [X] T002 [P] Create `unattended/README.md` documenting the three
       sub-products.
- [X] T003 [P] Create `bin/dc-audit.sh` skeleton (standalone-runnable).
- [X] T004 [P] Create `tests/test-ralph.sh` and `tests/test-dc-audit.sh`
       skeletons.

## Phase 2: Foundational

- [X] T005 Implement `bootstrap/symlinks.sh::_setup_unattended` (deploys
       `~/.unattended/`, vendors logging.sh, chmod +x).
- [X] T006 Wire opt-in gate: `[[ "${DOTFILES_INSTALL_UNATTENDED:-0}" == "1" ]]`
       guard in create_symlinks.
- [X] T007 [P] Implement install.sh CLI flag parsing
       (`--with-unattended` / `--without-unattended`).

## Phase 3: User Story 1 - Opt-in deploy (Priority: P1)

### Tests for User Story 1

- [X] T008 [P] [US1] Test: `./install.sh` (no flag) -> ~/.unattended does
       not exist.
- [X] T009 [P] [US1] Test: `./install.sh --with-unattended` -> ralph.sh
       deployed and executable.
- [X] T010 [P] [US1] Test: lib/logging.sh present and identical to
       bootstrap/logging.sh.

### Implementation for User Story 1

- [X] T011 [US1] In _setup_unattended, deploy_configs from `unattended/`
       (rubric, allowlist as files; scripts/templates/bootstrap/hooks
       as dirs).
- [X] T012 [US1] Vendor logging.sh: `cp -f bootstrap/logging.sh
       ~/.unattended/lib/logging.sh`.
- [X] T013 [US1] chmod +x scripts/* and bootstrap/*.

## Phase 4: User Story 2 - ralph.sh (Priority: P1)

### Tests for User Story 2

- [X] T014 [P] [US2] Test: 3-task PRD with passing verify -> ralph
       commits and exits 0.
- [X] T015 [P] [US2] Test: max iterations -> exit 2.
- [X] T016 [P] [US2] Test: wall-clock exceeded -> exit 3.
- [X] T017 [P] [US2] Test: single iteration timeout -> exit 4.
- [X] T018 [P] [US2] Test: 3 consecutive stalls -> exit 5.
- [X] T019 [P] [US2] Test: session budget exceeded -> exit 6.
- [X] T020 [P] [US2] Test: Claude error -> exit 1.

### Implementation for User Story 2

- [X] T021 [US2] Implement ralph.sh argument parsing.
- [X] T022 [US2] Implement iteration loop: orient -> plan -> implement ->
       verify -> commit-or-skip -> learn.
- [X] T023 [US2] Implement each safety gate as a separate function with
       its documented exit code.
- [X] T024 [US2] Implement progress.txt updates after each iteration.
- [X] T025 [US2] Implement ralph-parallel.sh: launch N ralph instances
       on separate worktrees.
- [X] T026 [US2] Source ralph-spec.sh for YAML frontmatter parsing of
       PRD.

## Phase 5: User Story 3 - dc-audit (Priority: P1)

### Tests for User Story 3

- [X] T027 [P] [US3] Test: missing --security-opt=no-new-privileges in
       unattended profile -> WARN, exit non-zero with --strict.
- [X] T028 [P] [US3] Test: --fix adds missing shutdownAction without
       modifying existing keys.
- [X] T029 [P] [US3] Test: standalone usage in a repo without dotfiles
       installed.
- [X] T030 [P] [US3] Test: --json emits valid JSONL.

### Implementation for User Story 3

- [X] T031 [US3] Implement rubric loader (jq-based) consuming
       `unattended/devcontainer-rubric.json`.
- [X] T032 [US3] Implement per-rule check functions.
- [X] T033 [US3] Implement --fix engine: additive only (use jq to
       merge missing keys; never delete or overwrite).
- [X] T034 [US3] Implement --strict (exit non-zero on any WARN) and
       --json (JSONL output).
- [X] T035 [US3] Implement --profile attended | unattended dispatch.

## Phase 6: User Story 4 - Hardened unattended profile (Priority: P1)

### Tests for User Story 4

- [X] T036 [P] [US4] Test: spin up unattended profile; assert cap drops
       active (`capsh --print` inside container).
- [X] T037 [P] [US4] Test: curl evil.example.com from inside container
       -> mitmproxy blocks within 1s.
- [X] T038 [P] [US4] Test: no `~/.ssh`, `~/.config/gh`, `~/.aws`
       mounts present in container.

### Implementation for User Story 4

- [X] T039 [US4] Author `.devcontainer/unattended/devcontainer.json`
       with runArgs + containerEnv + postCreateCommand sequence.
- [X] T040 [US4] Implement `unattended/bootstrap/unattended-deps.sh`
       (pip-audit, cargo-audit, govulncheck, osv-scanner).
- [X] T041 [US4] Implement `unattended/bootstrap/unattended-proxy.sh`
       (install mitmproxy, install CA, start with allowlist).
- [X] T042 [US4] Maintain `unattended/egress-allowlist.txt` with at
       minimum: github.com, api.github.com, claude.ai
       endpoints, npm/pip/cargo/go module mirrors.

## Phase 7: User Story 5 - GH_TOKEN scope validation (Priority: P2)

### Tests for User Story 5

- [X] T043 [P] [US5] Test: GH_TOKEN with org-wide repo:* scope ->
       entrypoint rejects, ralph does not start.
- [X] T044 [P] [US5] Test: GH_TOKEN with single-repo fine-grained
       scope -> entrypoint allows.

### Implementation for User Story 5

- [X] T045 [US5] Implement `unattended/bootstrap/unattended-entrypoint.sh`
       that calls `gh api /user` and inspects scope headers before
       invoking ralph.
- [X] T046 [US5] Wire the entrypoint as the unattended profile's
       primary command.

## Phase 8: Polish

- [X] T047 Document harness in repo README.md "Two products" section.
- [X] T048 Document Tier 2 in `unattended/planning/2026-04-19-unattended-stack-maturity.md`.
- [X] T049 Run `make lint`; expect 0 warnings.
- [X] T050 Run `make test` (test-ralph and test-dc-audit included);
       expect green.
- [X] T051 Run `make lint-devcontainers` (now a prerequisite of `make lint`;
       Error severity blocks, Warn/Info advise); address findings on
       attended/unattended profiles.
- [X] T052 Add `attended-bad.json` fixture and assertions covering the
       six new dc-audit rules (`runargs-privileged`,
       `runargs-cap-sys-admin`, `runargs-seccomp-unconfined`,
       `host-creds-mount-attended`, `docker-sock-mount`, `broad-home-mount`).
- [X] T053 Add `tests/test-dc-audit.sh` assertion: profile-to-directory
       mapping (`.devcontainer/unattended/*` -> unattended; other
       `.devcontainer/*` -> attended).

## Dependencies & Execution Order

- Phase 1 + 2 (foundation) blocks everything.
- Phase 3 (opt-in) blocks Phases 4-7 from being deployable.
- Phases 4 (ralph), 5 (dc-audit), 6 (unattended profile) can proceed
  in parallel -- different files, no shared in-memory state.
- Phase 7 (GH_TOKEN) depends on Phase 6 (the entrypoint runs in the
  unattended profile).
- Phase 8 polish runs last.

## Parallel Example

Phases 4, 5, 6 (ralph, dc-audit, unattended profile):
- T021-T026 modify only ralph.sh and friends.
- T031-T035 modify only dc-audit.sh.
- T039-T042 modify only the unattended devcontainer/bootstrap files.
All three can be authored by separate agents simultaneously.

## Implementation Strategy

- **MVP**: User Stories 1 + 2. Opt-in deploy + working ralph against
  a simple PRD. Ship this before anything else.
- **Iter 2**: User Story 3 (dc-audit). Useful standalone; doesn't
  require running unattended yet.
- **Iter 3**: User Story 4 (unattended profile + mitmproxy). The
  full sandboxed unattended experience.
- **Iter 4**: User Story 5 (GH_TOKEN scope). Defense-in-depth against
  over-scoped tokens.
- **Tier 2** (separate spec): cross-loop context, fine-grained
  per-task egress allowlists, parallel-loop coordinator. Tracked via
  `checklists/tier-2-trust-model.md`.
