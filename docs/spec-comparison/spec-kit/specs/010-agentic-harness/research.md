# Research: Agentic Harness

## Q1: Why opt-in instead of default-on?

**Decision**: `--with-agentic` opt-in. Mainstream installs do NOT
deploy the harness.

**Rationale**:

- Most users running these dotfiles want terminal QoL + Claude Code
  config. They are NOT running Claude autonomously overnight. The
  harness is meaningful only when there's no human reviewing every
  step.
- The harness deploys an autonomous loop runner (`ralph.sh`). On a
  shared workstation, an unprivileged process being able to invoke
  `~/.agentic/scripts/ralph.sh` is a non-trivial security surface.
  Default-off keeps that surface dormant.
- Users who do want it have a clean opt-in path:
  `--with-agentic` flag, or `DOTFILES_INSTALL_AGENTIC=1` in
  `containerEnv` for unattended profiles.
- The constitution's Article V mandates opt-in for high-risk surface;
  this capability is the exemplar.

**Trade-off**: Discoverability. Users may not realize the harness
exists. Mitigated by README.md's "Two products in this repo"
preamble naming the harness explicitly.

## Q2: Why three sub-products under one capability instead of three capabilities?

**Decision**: ralph + dc-audit + unattended profile = one capability.

**Rationale**:

- They share a deployment path (`~/.agentic/`).
- They share a threat model: autonomous Claude Code execution where
  no human is reviewing.
- The unattended profile consumes the rubric (via dc-audit) and
  invokes ralph.
- Splitting them across three capabilities would force three places
  to document the same threat model and three changesets to update
  when the model evolves.

**Trade-off**: Capability cohesion. The capability is bigger than
others; spec.md has 5 user stories instead of the typical 3-4.
Acceptable given the shared semantics.

## Q3: Why does dc-audit live in `bin/` instead of `agentic/`?

**Decision**: `bin/dc-audit.sh` is at the repo root, not under
`agentic/`.

**Rationale**:

- dc-audit is useful for auditing devcontainer.json files in any
  repo, by any developer, regardless of whether they opt into the
  agentic harness.
- Putting it under `agentic/` would force every developer who wants
  to lint a devcontainer.json to first opt into the autonomous loop
  runner. That's a bad UX.
- The rubric (`devcontainer-rubric.json`) lives in `agentic/`
  because the most demanding rubric profile is the unattended one --
  the rubric and the unattended profile are designed together.
- dc-audit reads the rubric from a few candidate locations:
  `agentic/devcontainer-rubric.json` (when run from a checkout),
  `~/.agentic/devcontainer-rubric.json` (when the harness is
  deployed). It works standalone in either case.

**Trade-off**: Discoverability split. dc-audit is in `bin/` but the
rubric it consumes lives in `agentic/`. Users who pull dc-audit out
to use elsewhere need to copy the rubric too. Acceptable given the
mainstream-developer benefit of dc-audit being available without
opting into the harness.

## Q4: Why mitmproxy with an allowlist instead of just `--network=none`?

**Decision**: Egress allowlist via mitmproxy, not network isolation.

**Options considered**:

1. **`--network=none`**. Container has no outbound network. **Problem**:
   Claude Code calls Anthropic's API; ralph clones repos and pushes
   to GitHub; dependency installers fetch from PyPI/npm/cargo. None
   of this works.
2. **Allowlist via iptables / nftables in container**. Lower
   overhead but requires `--cap-add=NET_ADMIN`, which weakens the
   cap-drop posture.
3. **mitmproxy with allowlist (chosen)**. Standard Linux network +
   mitmproxy intercepts all HTTP/HTTPS, applies allowlist, logs
   everything. No container capabilities needed beyond the default
   minimal set.

**Rationale**:

- Allowlist enforcement is at the proxy layer; cap drops stay strict
  in the container.
- Logging is built in -- every request is captured for after-the-fact
  audit.
- Bypass requires either disabling the CA trust (which we control on
  install) or an out-of-band channel (DNS exfil, ICMP). The latter
  is a known limitation; mitigated by `--cap-drop=ALL` blocking raw
  sockets.

**Trade-off**: TLS interception adds latency (~5-10ms per request).
Acceptable for autonomous workloads; not for low-latency interactive.

## Q5: Why fine-grained per-run GH_TOKEN instead of host-wide?

**Decision**: GH_TOKEN passed via `localEnv.GH_TOKEN_UNATTENDED`,
expected to be a single-repo fine-grained PAT, validated by
unattended-entrypoint.sh.

**Rationale**:

- A PAT with `repo` scope on a single repo limits blast radius if
  ralph goes off the rails (or if the unattended profile is
  compromised).
- Org-wide tokens would let a misbehaving ralph push to any repo in
  the org. Reading the token's scope before ralph starts catches
  this.
- `localEnv` rather than `containerEnv` means the token comes from
  the host's env at container-start time, not baked into the image.

**Trade-off**: User must rotate fine-grained PATs per-task. More
friction than reusing a long-lived org PAT. Acceptable given the
blast-radius reduction.

## Q6: Why is Tier 2 separate?

**Decision**: Tier 2 (cross-loop context, expanded trust model) is a
separate change proposal (`tier-2-trust-model`), not an amendment to
this spec.

**Rationale**:

- Tier 1 is shipped and stable. Adding Tier 2 features in-place would
  require modifying every existing FR and re-running the entire test
  suite for backwards compatibility.
- The Tier 2 work has unresolved unknowns (cross-loop context-
  sharing protocol, parallel coordinator design). These are tracked
  in `checklists/tier-2-trust-model.md` and need clarification before
  spec.md can absorb them.
- The Constitution Check for Tier 2 introduces new violations
  (cross-loop coordinator weakens isolation). These belong in a new
  Complexity Tracking row, not retrofitted into this spec.

**Trade-off**: Reviewers must read both this spec AND the Tier 2
checklist to understand the harness's full direction. Mitigated by
the plan.md Complexity Tracking row pointing forward to the
checklist.
