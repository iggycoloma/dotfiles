# Checklist: Security - Unattended Harness

**Purpose**: Pre-merge gate for any change touching `unattended/`,
`bin/dc-audit.sh`, or `.devcontainer/unattended/`. The harness is the
high-risk surface the constitution specifically calls out.

**Feature**: 010-unattended-harness
**Date created**: 2026-04-15
**Links**: [spec.md](../spec.md), [plan.md](../plan.md),
          [tasks.md](../tasks.md), [research.md](../research.md),
          [data-model.md](../data-model.md),
          [dc-audit-rule contract](../contracts/dc-audit-rule.md)

## Category 1: Opt-in posture

- [ ] CHK001 Change does NOT cause `~/.unattended/` to deploy by
       default; opt-in gate (`DOTFILES_INSTALL_UNATTENDED=1`) still
       holds.
- [ ] CHK002 Change does NOT add a new opt-in path that bypasses
       the existing flag (no `DOTFILES_INSTALL_UNATTENDED_LEGACY=1`,
       no `--unattended-yolo`).

## Category 2: Sandbox posture (unattended profile)

- [ ] CHK003 If the change modifies `.devcontainer/unattended/devcontainer.json`,
       `--cap-drop=ALL` is still in `runArgs`.
- [ ] CHK004 `--security-opt=no-new-privileges` still in `runArgs`.
- [ ] CHK005 No new mounts of `~/.ssh`, `~/.config/gh`, `~/.aws`,
       `~/.docker/config.json`, or other host credential paths.
- [ ] CHK006 `containerEnv` still sets `CLAUDE_UNATTENDED=1`.
- [ ] CHK007 No new `--privileged`, `--cap-add=SYS_ADMIN`, or other
       privilege-escalating runArgs.

## Category 3: Egress allowlist

- [ ] CHK008 If the change adds hosts to
       `unattended/egress-allowlist.txt`, each new host has a comment
       on the preceding line explaining why (which tool needs it).
- [ ] CHK009 No wildcards or regex in the allowlist (allowlist is
       hostname-exact only).
- [ ] CHK010 No new hosts that would allow data exfiltration to a
       generic destination (pastebin services, generic file hosts,
       URL shorteners).
- [ ] CHK011 If the change modifies `unattended-proxy.sh`, mitmproxy
       is still configured to log every request.

## Category 4: GH_TOKEN handling

- [ ] CHK012 If the change touches token-handling code (entrypoint,
       ralph), `GH_TOKEN_UNATTENDED` is still scope-validated before
       ralph starts.
- [ ] CHK013 No new token-source path (env var, file) that bypasses
       scope validation.
- [ ] CHK014 No token logging (stdout, log files, mitmproxy capture).

## Category 5: ralph safety gates

- [ ] CHK015 If the change modifies `ralph.sh`, all 7 safety gates
       (completion, max iters, wall clock, iter timeout, circuit
       breaker, session budget, Claude error) are still wired with
       their documented exit codes.
- [ ] CHK016 No new code path that allows ralph to commit without a
       passing verify.
- [ ] CHK017 No new code path that allows ralph to push without
       human approval.

## Category 6: dc-audit fix correctness

- [ ] CHK018 If the change adds a rule with `fix_expression`, the
       expression is verified to be purely additive (no overwrite,
       no removal).
- [ ] CHK019 The new rule has at least one positive (rule passes) and
       one negative (rule fails) test case in `tests/test-dc-audit.sh`.
- [ ] CHK020 The fix is tested with a "before" devcontainer.json
       fixture and an "after" snapshot; jq diff shows only additions.

## Category 7: Tier 2 work (in flight)

- [ ] CHK021 If the change is part of Tier 2 work
       (`tier-2-trust-model`), it includes a row in plan.md
       Complexity Tracking explaining the new constraint loosening
       (cross-loop coordinator weakens isolation).
- [ ] CHK022 Tier 2 work does NOT loosen Tier 1 invariants
       (cap drops, mitmproxy allowlist, no host credential mounts,
       GH_TOKEN scope validation).

## Notes

- Use `[X]` to mark complete; `[!]` for "not applicable to this
  change" with a one-line note.
- The harness is the constitution's Article V exemplar. Failing
  any item in this checklist is grounds for blocking the PR.
- If a category does not apply (e.g. the change is doc-only),
  mark every item `[!]` with a note like "doc-only change".
