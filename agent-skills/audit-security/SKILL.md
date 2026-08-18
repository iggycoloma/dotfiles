---
name: audit-security
description: Evidence-driven security audit for a repository, subsystem, advisory, or security-focused change. Use on explicit security-review requests; prefer review-pr for routine diffs that merely touch security-sensitive code.
---

# Security audit

Find plausible vulnerabilities and control gaps without reading prohibited secrets or turning generic best practices into findings.

## Scope and precedence

- Use the target named by the user; if none is given, audit the current repository.
- For an ordinary PR or working diff, use `review-pr` unless the user explicitly requests a security audit or the change is primarily about authentication, authorization, cryptography, or secret handling.
- State the trust boundary, attacker-controlled inputs, protected assets, and code or configuration in scope before judging controls.
- Follow all repository credential deny lists. Never open `.env` files, credentials, private keys, token stores, cloud configuration, or other prohibited paths. Their presence or absence can be checked only through permitted metadata or tracked-path searches when policy allows it.

## Audit lanes

Select lanes that apply to the system rather than mechanically enumerating a checklist:

1. Input reaches interpreters: shell, SQL, templates, HTML, paths, URLs, deserializers, and dynamic evaluation.
2. Authentication and session lifecycle: identity proof, token issuance, rotation, expiry, recovery, and fixation.
3. Authorization: object ownership, tenant boundaries, role transitions, administrative paths, and background workers.
4. Data exposure: logs, errors, caches, telemetry, exports, backups, and client-visible responses.
5. Network boundaries: SSRF, redirects, webhook verification, origin policy, proxy trust, and outbound destinations.
6. Cryptography and integrity: primitive selection, nonce and randomness use, signature verification, downgrade behavior, and supply-chain integrity.
7. Dependencies: authoritative advisories, affected versions, reachability, mitigations, and fixed releases.
8. Operational failure: whether rejected or suspicious activity is visible and whether security controls fail open.

Use language- and framework-specific knowledge only after confirming that the repository actually uses that mechanism and configuration.

## Evidence bar

Every finding must identify:

- The attacker-controlled input or precondition.
- The exact path to the vulnerable operation or missing authorization decision.
- The resulting impact.
- The file and line supporting the claim.
- A smallest correct remediation and how to verify it.

Verify framework defaults and compensating controls from the repository's actual configuration. If exploitability depends on unavailable deployment state, label it `needs verification` rather than asserting a vulnerability. Drop theoretical findings without a concrete path.

Never print suspected secret values. If permitted scanning reports a possible credential, cite only the file and detector category and advise rotation through the appropriate human-controlled process.

## Severity

Use Critical, High, Medium, or Low based on realistic impact, exploitability, required privileges, and existing mitigations. Do not assign an overall risk grade when the scope or deployment evidence is insufficient.

## Report

List findings worst first. For each include severity, location, attack path, impact, evidence, remediation, and verification. Then include:

- Controls verified and left alone.
- Unknowns that require deployment or organizational evidence.
- Checks run and checks skipped.

If nothing survives verification, say so and name the lanes inspected; do not claim the system is secure.
