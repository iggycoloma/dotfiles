# Implementation Plan: Agentic Harness

**Branch**: `010-agentic-harness` | **Date**: 2026-04-15 | **Spec**: [spec.md](./spec.md)

## Summary

Opt-in harness for autonomous Claude Code execution. Three components:
ralph.sh (loop with 7 safety gates), dc-audit.sh (devcontainer linter
with additive `--fix`), unattended devcontainer profile (cap drops,
mitmproxy egress allowlist, scoped per-run GH_TOKEN). Lives in
`agentic/` in the repo; deploys to `~/.agentic/` only when
`--with-agentic`. Tier 2 work (cross-loop context, expanded trust
model) is in flight via a separate change proposal -- see Complexity
Tracking.

## Technical Context

| Field             | Value                                                                              |
|-------------------|------------------------------------------------------------------------------------|
| Language/Version  | Bash for ralph and dc-audit; JSON for rubric and devcontainer.json                 |
| Dependencies      | claude CLI, jq, gitleaks, docker (for unattended profile), mitmproxy, GitHub CLI   |
| Storage           | `~/.agentic/`; per-iteration progress.txt in workspace                             |
| Testing           | `tests/test-ralph.sh`, `tests/test-dc-audit.sh`                                   |
| Target Platform   | Linux containers (unattended profile); ralph runs anywhere                         |
| Project Type      | Single Project                                                                     |
| Performance Goals | ralph iteration overhead <30s; dc-audit run <1s for typical .devcontainer/         |
| Constraints       | Defaults must remain off; cap drops cannot break `git`/`make`; egress allowlist must include GitHub |
| Scale/Scope       | 3 tools (ralph, dc-audit, profile), 7 safety gates, ~25 audit rules, ~40 allowlist hosts |

## Constitution Check

| Article                            | Status | Notes                                                                       |
|------------------------------------|--------|------------------------------------------------------------------------------|
| I. Developer-Specific              | PASS   | Universal autonomous-Claude tooling; deploys to ~/.agentic, not project.    |
| II. Defense-in-Depth Security      | PASS   | Cap drops + mitmproxy + GH_TOKEN scope validation = three independent layers. |
| III. Cross-Platform Parity         | N/A    | Unattended profile is Linux containers only; ralph runs on any bash 3.2+.   |
| IV. Idempotent and Reversible      | PASS   | Re-deploy is no-op; `--without-agentic` removes nothing (clean uninstall via separate path). |
| V. Opt-In for High-Risk Surface    | PASS   | This IS the high-risk surface that justifies Article V. Default-off is non-negotiable. |

## Project Structure

```
agentic/
|-- README.md
|-- scripts/
|   |-- ralph.sh
|   |-- ralph-parallel.sh
|   +-- ralph-spec.sh
|-- templates/
|   |-- PRD.md, PROMPT.md, progress.txt
|-- bootstrap/
|   |-- unattended-deps.sh
|   |-- unattended-proxy.sh
|   +-- unattended-entrypoint.sh
|-- devcontainer-rubric.json
|-- egress-allowlist.txt
+-- planning/                    Design notes; out-of-band of specs
bin/
+-- dc-audit.sh                  Standalone (does not require ~/.agentic/)
.devcontainer/
+-- unattended/devcontainer.json
```

### Structure Decision

Single Project. The harness has three sub-products that share the
deployment but are independently usable:
- ralph (loop runner, ~/.agentic/scripts/)
- dc-audit (lint tool, lives in repo's `bin/` because it should work
  standalone)
- unattended profile (.devcontainer/unattended/, consumed by docker)

## Complexity Tracking

| Violation                                                                | Why Needed                                                                                                                                                                          | Simpler Alternative Rejected Because                                                                                                                          |
|--------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Three independent sub-products under one capability                      | They share the deployment path (`~/.agentic/`) and the threat model (autonomous Claude). Splitting them across three capabilities would obscure the shared rubric / allowlist /  trust assumptions. | Three separate capabilities lose the unifying threat model and end up with duplicated docs.                                                                   |
| dc-audit lives in `bin/` (root) but the rubric lives in `agentic/`       | dc-audit must be runnable in any repo for any developer auditing their own devcontainer.json -- moving it under `agentic/` would force every developer to opt into the harness just to lint a devcontainer. | Putting both under `agentic/` (rubric + tool together) makes dc-audit unavailable to mainstream developers; we'd lose a major safety surface.                |
| **Tier 2 work in flight (NOT YET MERGED)**: trust model expansion        | Current trust model is binary (attended/unattended). Tier 2 introduces fine-grained trust: per-task egress allowlists, per-loop credential scoping, cross-loop coordinator.       | Punting Tier 2 leaves real gaps in autonomous-Claude safety (parallel loops can read each other's plans). See `tier-2-trust-model` checklist for the work plan. |

> Tier 2 progress is tracked in `checklists/tier-2-trust-model.md`. The
> spec above describes the as-built Tier 1 surface; FRs corresponding
> to Tier 2 will be added once the work merges.
