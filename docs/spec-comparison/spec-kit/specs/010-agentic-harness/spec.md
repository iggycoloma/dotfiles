# Feature Specification: Agentic Harness

**Branch**: `010-agentic-harness` | **Date**: 2026-04-15 | **Status**: Implemented (Tier 1); Tier 2 in flight (see plan.md Complexity Tracking and the pending `tier-2-trust-model` checklist)

## User Scenarios & Testing

### User Story 1 - Opt-in deploy via flag (Priority: P1)

A developer who runs Claude Code autonomously wants the harness
deployed to `~/.agentic/` without polluting installs for users who
just want terminal QoL.

**Why this priority**: Default-on would deploy the autonomous loop
runner to every developer machine, which is both confusing and
risky. The opt-in is the only acceptable default behavior.

**Independent Test**: Run `./install.sh` (no flag); assert
`~/.agentic/` does not exist. Run `./install.sh --with-agentic`;
assert `~/.agentic/scripts/ralph.sh` is executable.

**Acceptance Scenarios**:
```
GIVEN a host without DOTFILES_INSTALL_AGENTIC set
WHEN ./install.sh runs without --with-agentic
THEN ~/.agentic/ is not created
  AND the installer logs "Agentic Harness: disabled"
```

```
GIVEN a host install
WHEN ./install.sh --with-agentic runs
THEN ~/.agentic/scripts/ralph.sh is deployed and executable
  AND ~/.agentic/devcontainer-rubric.json is deployed
  AND ~/.agentic/lib/logging.sh is vendored from bootstrap/logging.sh
```

### User Story 2 - Autonomous loop with safety gates (Priority: P1)

A developer can run `ralph.sh` against a PRD and have Claude Code
iterate (orient, plan, implement, verify, commit, learn) until done
or until any of seven safety gates fire.

**Why this priority**: This is the headline capability. Without it the
harness has no reason to exist.

**Independent Test**: Run `ralph.sh` with a small PRD that has a
verifiable test; assert it commits and exits 0 when the test passes.
Inject failures to trigger each safety gate (max iters, wall clock,
circuit breaker, etc.) and assert correct exit codes.

**Acceptance Scenarios**:
```
GIVEN ralph is running with --session-budget 5 --max-wall-clock 3600
  AND the PRD has 3 tasks each verifiable by `make test`
WHEN ralph runs
THEN each iteration: orients, plans, implements, runs `make test`,
  AND commits if green, records learnings, repeats
  AND on completion ralph exits 0
```

```
GIVEN ralph is running with circuit-breaker threshold 3
  AND three consecutive iterations produce no commit and no progress.txt update
WHEN the fourth iteration begins
THEN ralph halts with exit code 5
  AND logs "Circuit breaker: 3 consecutive stalls"
```

### User Story 3 - dc-audit lints devcontainer.json (Priority: P1)

A developer can audit any `devcontainer.json` against best practices
(image pinning, security flags, resource caps, no host credential
mounts in unattended profile) and apply additive auto-fixes.

**Why this priority**: Misconfigured devcontainers are the most
likely path to autonomous-Claude exfiltration. Catching issues
before deploy is critical.

**Independent Test**: Run `dc-audit.sh --profile unattended` against
a profile missing `--security-opt=no-new-privileges`; assert
non-zero exit with `--strict`.

**Acceptance Scenarios**:
```
GIVEN .devcontainer/foo/devcontainer.json lacks --security-opt=no-new-privileges
WHEN bin/dc-audit.sh --profile unattended --strict .devcontainer/foo/devcontainer.json runs
THEN dc-audit reports "WARN: missing --security-opt=no-new-privileges"
  AND exits non-zero
```

```
GIVEN a devcontainer.json missing shutdownAction
WHEN dc-audit.sh --fix runs
THEN shutdownAction is added to the JSON (top-level key)
  AND no existing key is modified
  AND no key is removed
```

### User Story 4 - Hardened unattended profile with mitmproxy (Priority: P1)

A developer can spin up a devcontainer that drops capabilities,
enforces resource caps, mounts no host credentials, and routes all
egress through mitmproxy with a documented allowlist.

**Why this priority**: Without sandboxing, autonomous Claude has
unbounded outbound access. The unattended profile is the trust
boundary.

**Independent Test**: Spin up `.devcontainer/unattended/`, attempt
`curl https://evil.example.com/` from inside; assert mitmproxy blocks
and logs.

**Acceptance Scenarios**:
```
GIVEN the unattended devcontainer is running
  AND mitmproxy is running with agentic/egress-allowlist.txt
  AND evil.example.com is not in the allowlist
WHEN code in the container runs `curl https://evil.example.com/`
THEN mitmproxy blocks the connection
  AND logs the blocked attempt
  AND curl exits with a connection error
```

### User Story 5 - GH_TOKEN scope validation (Priority: P2)

A developer running ralph in the unattended profile passes
`GH_TOKEN_UNATTENDED` per-run. The entrypoint validates that the
token's scope matches expectations (single-repo fine-grained token)
before ralph starts.

**Acceptance Scenarios**:
```
GIVEN GH_TOKEN_UNATTENDED is a token with org-wide repo:* scope
WHEN unattended-entrypoint.sh runs
THEN scope validation rejects the token
  AND ralph does NOT start
  AND the entrypoint exits non-zero
```

### Edge Cases

- **ralph SIGTERM mid-iteration**: cleanup the iteration's working
  state; do not commit a partial.
- **Verify command times out**: count as a "stall" toward circuit
  breaker; do not commit.
- **mitmproxy crash**: container egress fails closed (cannot reach
  even allowlisted hosts); ralph treats this as a safety gate and
  exits.
- **dc-audit on a profile that already passes**: report all
  `OK`, exit 0.
- **`--with-agentic` on a host without git**: harness still deploys;
  ralph won't run without git but the install completes.

## Requirements

### Functional Requirements

#### Deployment

- **FR-001** Installer MUST NOT deploy `~/.agentic/` unless
  `DOTFILES_INSTALL_AGENTIC=1` is set.
- **FR-002** `--with-agentic` flag MUST set `DOTFILES_INSTALL_AGENTIC=1`.
- **FR-003** `--without-agentic` MUST set `DOTFILES_INSTALL_AGENTIC=0`.
- **FR-004** Unattended profile MUST set `DOTFILES_INSTALL_AGENTIC=1`
  in `containerEnv`.
- **FR-005** Deployed `~/.agentic/` MUST contain scripts/, templates/,
  bootstrap/, hooks/, devcontainer-rubric.json, egress-allowlist.txt,
  lib/logging.sh.
- **FR-006** All scripts in scripts/ and bootstrap/ MUST be executable.

#### ralph.sh

- **FR-007** ralph.sh MUST accept --prompt-file, --prd, --spec-file,
  --verify-cmd, --session-budget, --max-wall-clock arguments.
- **FR-008** Each ralph iteration MUST: orient on progress.txt, plan,
  implement, run verify, commit if verify passes, record learnings.
- **FR-009** ralph MUST halt on: completion, max iterations, total
  wall-clock exceeded, single iteration timeout, circuit breaker (N
  stalls), session budget exceeded, Claude error, safety gate.
- **FR-010** ralph MUST exit 0 on completion; 1 on Claude/safety; 2
  on iter limit; 3 on wall-clock; 4 on iter timeout; 5 on circuit
  breaker; 6 on session budget.
- **FR-011** ralph-parallel.sh MUST launch N ralph instances on
  separate git worktrees.

#### dc-audit.sh

- **FR-012** dc-audit MUST consume rules from `agentic/devcontainer-rubric.json`.
- **FR-013** dc-audit MUST support `--profile attended | unattended`
  (default attended).
- **FR-014** Unattended profile MUST add: cap drops, no host credential
  mounts, mitmproxy expectation.
- **FR-015** dc-audit MUST support `--fix` (additive only; never
  overwrite or remove).
- **FR-016** dc-audit MUST support `--strict --json` (non-zero on
  warn; JSONL output).
- **FR-017** dc-audit MUST work standalone (does not require
  full dotfiles install).

#### Unattended profile

- **FR-018** runArgs MUST include `--cap-drop=ALL`,
  `--security-opt=no-new-privileges`, `--pids-limit=1024`, resource
  caps.
- **FR-019** containerEnv MUST set `CLAUDE_UNATTENDED=1` and
  `DOTFILES_INSTALL_AGENTIC=1`.
- **FR-020** postCreateCommand MUST run install.sh --with-agentic ->
  unattended-deps.sh -> unattended-proxy.sh.
- **FR-021** No mounts of `~/.ssh`, `~/.config/gh`, `~/.aws` from
  host.
- **FR-022** GH_TOKEN MUST come from `localEnv.GH_TOKEN_UNATTENDED`.

#### mitmproxy egress

- **FR-023** unattended-proxy.sh MUST install mitmproxy + CA into
  container trust store + start mitmproxy with allowlist.
- **FR-024** Every HTTP/HTTPS request MUST be logged.
- **FR-025** Hosts not in allowlist MUST be blocked.

#### Unattended deps

- **FR-026** unattended-deps.sh MUST install pip-audit, cargo-audit,
  govulncheck, osv-scanner.
- **FR-027** unattended-entrypoint.sh MUST validate GH_TOKEN scope
  before ralph; fail closed on unexpected scope.

### Key Entities

- **Iteration**: orient -> plan -> implement -> verify -> commit-or-skip ->
  learn cycle. Tracked in `progress.txt`.
- **Safety gate**: a halt condition. Seven distinct gates with
  documented exit codes.
- **dc-audit rule**: `{id, severity, description, applies_to, fix_expression}`
  -- see contracts/dc-audit-rule.md.
- **Egress allowlist entry**: a hostname (no port; no path); mitmproxy
  permits any HTTP/HTTPS request to a listed host.

## Success Criteria

- **SC-001** Default install does NOT deploy `~/.agentic/` (verified
  in CI on every matrix cell).
- **SC-002** ralph completes a 3-task PRD with verify-passing in <10
  iterations on the smoke test.
- **SC-003** Each of the 7 safety gates triggers correctly in
  `tests/test-ralph.sh` (mocked Claude responses).
- **SC-004** dc-audit catches every rule violation in
  `tests/test-dc-audit.sh` fixture set.
- **SC-005** Unattended profile blocks egress to a non-allowlisted
  host within 1s in the integration test.
- **SC-006** GH_TOKEN scope validation rejects org-wide tokens in
  100% of test cases.
- **SC-007** dc-audit `--fix` is purely additive (test: no existing
  values modified, no keys removed) -- verified with `jq` diff
  comparison.

## Assumptions

- Claude Code's CLI accepts the args ralph passes
  (`--prompt-file`, etc.) -- contract documented in
  contracts/ralph-claude.md.
- mitmproxy 10.x is the supported version; CA installation works on
  Debian/Ubuntu base images (used in unattended profile).
- The user has docker available locally to run the unattended profile.
- The fine-grained-PAT model continues to be supported by GitHub.
- Network egress is the primary autonomous-Claude exfiltration vector
  (other vectors -- volume mounts, env vars -- are addressed by
  FR-021 and FR-022).
