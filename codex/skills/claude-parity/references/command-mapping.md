# Command Mapping

Use this table to map Claude-style command intent to Codex execution steps.

## context-prime

1. Read `README.md`, local `AGENTS.md`/`CLAUDE.md` if present.
2. Detect stack from manifests (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, etc.).
3. Report `git status --short`, current branch, and last 5 commits.
4. Summarize constraints, conventions, and what to work on next.

## commit

1. Inspect `git status` and staged/unstaged diff.
2. Infer conventional commit type and scope.
3. Present proposed commit message.
4. Run `git commit` with final message after user approval if requested.

## changelog

1. Collect commits since last tag (`git describe --tags --abbrev=0`).
2. Group entries by Added/Changed/Fixed/Security.
3. Produce Keep a Changelog formatted markdown entry.

## pr-create

1. Validate branch state and target base.
2. Summarize diffs and testing performed.
3. Draft complete PR title/body and include linked issues.
4. Run or output `gh pr create ...`.

## review-pr

1. Fetch change context with `gh pr view` / `gh pr diff`, `glab mr view` / `glab mr diff`, or the working diff against the repo's default base when no target is given.
2. Judge in order of how often it bites: correctness for untested cases, merge ordering, observability of failure, evidence for behaviour people rely on, repo fit at both altitudes (which utility *and* which mechanism), mechanism level, content levels, title durability.
3. Rank invariants by durability -- schema constraint -> type -> application code -> runtime coordination -- and flag a mechanism that reached lower than it needed to.
4. Then answer both halves once for the change as a whole: the smallest correct change, and the best available change with nothing off-limits (priced, capped at one, default non-blocking).
5. Label every finding blocking or non-blocking. No third, softer tier.
6. Drop any finding without evidence -- an input that produces the wrong result, or for a mechanism finding, the constraint or type that already carries the invariant, cited by name and file.

## debug

1. Gather error evidence and reproduction steps.
2. Form and test hypotheses.
3. Identify root cause (not just symptom).
4. Implement minimal fix and add regression test.
5. Verify with relevant commands.

## dependencies

1. Detect package ecosystem.
2. Check outdated and vulnerable dependencies.
3. Classify updates by risk (patch/minor/major).
4. Apply low-risk/security updates first and test.
5. Summarize changes and residual risk.

## feature-spec

1. Capture business goal and users.
2. Write stories + acceptance criteria.
3. Define functional and non-functional requirements.
4. Document constraints, edge cases, and out-of-scope.

## fix-issue

1. Fetch issue details (`gh issue view`).
2. Reproduce and isolate root cause.
3. Implement focused fix with tests.
4. Create branch/commit/PR with issue linkage.

## optimize

1. Establish baseline metrics.
2. Identify bottleneck with evidence.
3. Implement highest-impact optimization first.
4. Re-measure and report before/after.

## refactor

1. Confirm tests exist (or add them first).
2. Make small behavior-preserving improvements.
3. Validate after each logical change.
4. Keep scope constrained to identified smells.

## security-audit

1. Scan for hardcoded secrets and insecure patterns.
2. Review input validation, authn/authz, crypto usage, and logging exposure.
3. Check dependency CVEs.
4. Report by severity with remediation guidance.

## test

1. Identify changed logic and public surfaces.
2. Add/update tests for happy path, edge cases, and error cases.
3. Run the narrowest relevant test command first, then broader suite if needed.
4. Report coverage intent and results.
