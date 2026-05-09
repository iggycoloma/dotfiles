# Extract Agentic Harness -- Tasks (ARCHIVED)

## 1. New layout (PR #46)

- [X] 1.1 `git mv claude-code/scripts agentic/scripts` (preserves
       history).
- [X] 1.2 `git mv claude-code/templates agentic/templates`.
- [X] 1.3 `git mv claude-code/devcontainer-rubric.json
       agentic/devcontainer-rubric.json`.
- [X] 1.4 `git mv claude-code/egress-allowlist.txt
       agentic/egress-allowlist.txt`.
- [X] 1.5 `git mv claude-code/bootstrap agentic/bootstrap`.
- [X] 1.6 Create `agentic/README.md` introducing the harness as a
       separate product, with the three-entry-points layout
       (ralph, dc-audit, unattended profile).
- [X] 1.7 Create `bin/dc-audit.sh` standalone tool consuming the
       rubric. Read rubric from
       `agentic/devcontainer-rubric.json` (in-repo) or
       `~/.agentic/devcontainer-rubric.json` (deployed).

## 2. Installer wiring

- [X] 2.1 Add `--with-agentic` / `--without-agentic` flags to
       `install.sh` setting `DOTFILES_INSTALL_AGENTIC`.
- [X] 2.2 Add `_setup_agentic` to `bootstrap/symlinks.sh` deploying
       `~/.agentic/`, vendoring `bootstrap/logging.sh` to
       `~/.agentic/lib/logging.sh`, chmod +x scripts/ and bootstrap/.
- [X] 2.3 Wire `_setup_agentic` into `create_symlinks` gated on
       `[[ "${DOTFILES_INSTALL_AGENTIC:-0}" == "1" ]]`.
- [X] 2.4 Modify `_setup_claude_code` to no longer deploy
       templates/scripts/rubric/bootstrap (now handled by
       `_setup_agentic`).

## 3. Back-compat symlinks (transitional, PR #46 only)

- [X] 3.1 In `_setup_claude_code`, add transitional symlinks:
       `~/.claude/scripts -> ~/.agentic/scripts`,
       `~/.claude/templates -> ~/.agentic/templates`,
       `~/.claude/devcontainer-rubric.json ->
       ~/.agentic/devcontainer-rubric.json`. Only when both
       `~/.agentic/` and `~/.claude/` exist.
- [X] 3.2 Document the deprecation timeline (this PR introduces
       them; they will be removed in the follow-up PR).

## 4. Unattended devcontainer profile

- [X] 4.1 Create `.devcontainer/unattended/devcontainer.json` with:
       runArgs (cap drops, no-new-privileges, pids-limit, resource
       caps), containerEnv (`DOTFILES_INSTALL_AGENTIC=1`,
       `CLAUDE_UNATTENDED=1`), postCreateCommand running
       install.sh -> unattended-deps.sh -> unattended-proxy.sh.
- [X] 4.2 No mounts of `~/.ssh`, `~/.config/gh`, or `~/.aws`.
- [X] 4.3 GH_TOKEN comes from `localEnv.GH_TOKEN_UNATTENDED`.

## 5. Test updates

- [X] 5.1 Update `tests/test-install.sh` to assert `~/.agentic/`
       does NOT exist after default install.
- [X] 5.2 Add test: `./install.sh --with-agentic` -> ralph.sh
       deployed and executable.
- [X] 5.3 Update `tests/test-ralph.sh` to source vendored
       `~/.agentic/lib/logging.sh`.
- [X] 5.4 Update `tests/test-dc-audit.sh` to verify standalone
       operation (no dotfiles install).

## 6. Documentation

- [X] 6.1 Update README.md introducing "Two products in this repo"
       (P1: Dotfiles / terminal QoL; P2: Agentic harness).
- [X] 6.2 Update root AGENTS.md with the boundary.
- [X] 6.3 Add `make lint-devcontainers` advisory target.

## 7. Follow-up PR (#47): Remove back-compat symlinks

- [X] 7.1 Remove the transitional symlink lines from
       `_setup_claude_code` (introduced in 3.1).
- [X] 7.2 Remove "legacy rubric path" handling in `bin/dc-audit.sh`
       (the only non-`agentic/` lookup path).
- [X] 7.3 Update `tests/test-install.sh` to assert the legacy paths
       no longer exist.
- [X] 7.4 Document the removal in commit message
       ("chore: remove agentic back-compat symlinks and legacy
       rubric paths").
