---
name: manage-dependencies
description: Audit or update project dependencies using the repository's package managers, current advisories, upstream release notes, and risk-based validation. Use when the user asks about outdated, vulnerable, or upgraded dependencies.
---

# Dependencies

Audit or update dependencies without broadening the requested scope.

## Establish the ecosystem

1. Read repository instructions and dependency manifests without opening credential or secret files.
2. Identify the package manager from lockfiles and existing commands; do not substitute a different manager.
3. Identify runtime, development, generated, vendored, and workspace dependencies separately.
4. Record the repository's supported runtime versions and canonical test commands.

## Gather current evidence

- Use the package manager's native outdated and audit commands when available.
- For vulnerability or upgrade decisions, verify current advisories, fixed versions, release notes, and migration guides using authoritative sources.
- Distinguish a vulnerable version from an exploitable path. Report whether the affected package is direct or transitive, runtime or development-only, and reachable or of unknown reachability.
- Do not access registry credentials, local package-manager credential files, or secret-bearing environment files.
- Do not install optional audit utilities merely to complete the audit. State the gap and use available authoritative sources.

## Classify changes

Classify by evidence, not semantic-version labels alone:

- Urgent: exploitable vulnerability or known active compromise.
- Routine: compatible maintenance release with relevant fixes and low migration risk.
- Planned: behavior change, runtime/toolchain requirement, peer-dependency change, or migration work.
- Defer: no material benefit, unmaintained replacement without a safe migration, or insufficient evidence.

A patch release is not automatically safe, and a major release is not automatically unsafe.

## Update safely

1. Preserve manifest conventions and the existing lockfile.
2. Apply the smallest coherent dependency set; include coupled peer or lockfile changes only when required.
3. Do not mix unrelated upgrades.
4. Inspect install output and the resulting manifest and lockfile diff.
5. Run the narrowest checks covering the dependency's use, followed by broader repository checks when proportionate to risk.
6. For major or behavior-changing upgrades, verify affected call sites against upstream migration guidance.

Do not create a checkpoint commit unless the user requested a commit. Existing Git history already provides recovery for tracked clean state; uncommitted user work must be preserved.

## Report

Lead with vulnerabilities or blockers, then list updates by classification. For each material item include current and target versions, why it matters, compatibility or reachability evidence, files changed, validation results, and residual risk. Clearly separate changes made from recommendations only.
