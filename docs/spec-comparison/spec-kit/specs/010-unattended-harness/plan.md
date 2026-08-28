# Implementation Plan: Unattended Harness

**Branch**: `010-unattended-harness` | **Date**: 2026-04-22 (renamed from `010-agentic-harness`) | **Spec**: [spec.md](./spec.md)

## Summary

Opt-in harness for autonomous Claude Code execution.
Three components: ralph.sh (loop with 7 safety gates), dc-audit.sh (devcontainer linter with additive `--fix`; 20+ rules), unattended devcontainer profile (cap drops, mitmproxy egress allowlist, scoped per-run GH_TOKEN).
Lives in `unattended/` in the repo; deploys to `~/.unattended/` only when `--with-unattended`.
Tier 2 work (pre-flight estimate, cross-loop discoveries, phased iteration mode) is in flight via a separate change proposal -- see Complexity Tracking.
The capability was renamed from "agentic harness" to "unattended harness" in PR #53 to disambiguate from the broad "agentic" vocabulary covering Claude Code and Codex CLI.

## Technical Context

| Field             | Value                                                                              |
|-------------------|------------------------------------------------------------------------------------|
| Language/Version  | Bash for ralph and dc-audit; JSON for rubric and devcontainer.json                 |
| Dependencies      | claude CLI, jq, gitleaks, docker (for unattended profile), mitmproxy, GitHub CLI   |
| Storage           | `~/.unattended/`; per-iteration progress.txt in workspace                          |
| Testing           | `tests/test-ralph.sh`, `tests/test-dc-audit.sh`                                    |
| Target Platform   | Linux containers (unattended profile); ralph runs anywhere                         |
| Project Type      | Single Project                                                                     |
| Performance Goals | ralph iteration overhead <30s; dc-audit run <1s for typical .devcontainer/         |
| Constraints       | Defaults must remain off; cap drops cannot break `git`/`make`; egress allowlist must include GitHub |
| Scale/Scope       | 3 tools (ralph, dc-audit, profile), 7 safety gates, 20+ audit rules, ~40 allowlist hosts |

## Constitution Check

| Article                            | Status | Notes                                                                       |
|------------------------------------|--------|------------------------------------------------------------------------------|
| I. Developer-Specific              | PASS   | Universal autonomous-Claude tooling; deploys to ~/.unattended, not project. |
| II. Three-Tier Defense             | PASS   | Tier 1 (cap drops + no host-creds mounts), Tier 2 (mitmproxy + container boundary), Tier 3 (GH_TOKEN scope validation upstream of ralph). |
| III. Cross-Platform Parity         | N/A    | Unattended profile is Linux containers only; ralph runs on any bash 3.2+.   |
| IV. Idempotent and Reversible      | PASS   | Re-deploy is no-op; `--without-unattended` removes nothing (clean uninstall via separate path). |
| V. Opt-In for High-Risk Surface    | PASS   | This IS the high-risk surface that justifies Article V. Default-off is non-negotiable. |

## Project Structure

```
unattended/
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
+-- dc-audit.sh                  Standalone (does not require ~/.unattended/)
.devcontainer/
+-- unattended/devcontainer.json
```

### Structure Decision

Single Project.
The harness has three sub-products that share the deployment but are independently usable:
- ralph (loop runner, ~/.unattended/scripts/)
- dc-audit (lint tool, lives in repo's `bin/` because it should work standalone in any repo)
- unattended profile (.devcontainer/unattended/, consumed by docker)

## Complexity Tracking

| Violation                                                                  | Why Needed                                                                                                                                                                          | Simpler Alternative Rejected Because                                                                                                                          |
|----------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Three independent sub-products under one capability                        | They share the deployment path (`~/.unattended/`) and the threat model (autonomous Claude). Splitting them across three capabilities would obscure the shared rubric / allowlist / trust assumptions. | Three separate capabilities lose the unifying threat model and end up with duplicated docs.                                                                   |
| dc-audit lives in `bin/` (root) but the rubric lives in `unattended/`      | dc-audit must be runnable in any repo for any developer auditing their own devcontainer.json -- moving it under `unattended/` would force every developer to opt into the harness just to lint a devcontainer. | Putting both under `unattended/` (rubric + tool together) makes dc-audit unavailable to mainstream developers; we'd lose a major safety surface.              |
| Attended profiles have no network-layer egress enforcement                 | The previous iptables-based attended egress (`bootstrap/devcontainer-egress.sh`) was removed in PR #53 because the container itself is the trust boundary on hosts the user already trusts, and the iptables script was opt-in (most users never enabled it). dc-audit spec-linting is now the attended-profile defense. | Keeping the iptables script as a parallel defense led to confusion (two opt-in paths, neither widely used) and false confidence (off-by-default = no defense). |
| **Tier 2 work in flight (NOT YET MERGED)**: estimate + discoveries + phased | Current loop is single-prompt; lacks pre-flight cost estimation and cross-loop context. Tier 2 closes three gaps without weakening Tier 1's safety perimeter. All three Tier 2 features are opt-in. | Punting Tier 2 leaves real gaps: operators discover cost only after burning tokens; parallel loops cannot share learnings. See `tier-2-trust-model` checklist. |

> Tier 2 progress is tracked in `checklists/tier-2-trust-model.md`. The
> spec above describes the as-built Tier 1 surface; FRs corresponding
> to Tier 2 will be added once the work merges.
