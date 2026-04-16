---
description: |
  Review an existing pull request for correctness, security, performance, and
  maintainability. TRIGGER when the user mentions a PR by number (#NNN), PR URL
  (github.com/owner/repo/pull/N), or asks to "review PR" / "look at this PR".
  SKIP when the user is asking for a review of their local uncommitted changes
  (use simplify or a general code review instead) or for a security-specific
  deep dive (use security-audit).
argument-hint: <PR number or URL>
allowed-tools: Read, Bash(gh pr view:*, gh pr diff:*, gh pr checks:*, git log:*, git diff:*), Grep, Glob
---

You are reviewing an existing pull request for code quality, correctness, and security.

## Target

Use `$ARGUMENTS` as the PR number or URL. If no arguments, ask the user which PR to review.

## Process

### 1. Fetch PR Information
```bash
gh pr view $ARGUMENTS
gh pr diff $ARGUMENTS
gh pr checks $ARGUMENTS
```

### 2. Understand Context
- What is this PR trying to accomplish?
- Read the PR description and linked issues
- Check the branch name for intent (feat/, fix/, refactor/)

### 3. Review the Diff
For each changed file:
- **Correctness**: Does the code do what it claims? Are there logic errors?
- **Security**: Any new vulnerabilities? (injection, auth bypass, secrets, XSS)
- **Performance**: Any obvious bottlenecks? N+1 queries? O(n^2) in hot paths?
- **Maintainability**: Is the code readable? Good naming? Reasonable complexity?
- **Tests**: Are changes covered by tests? Are the tests meaningful?
- **Edge cases**: What happens with empty input, null values, concurrent access?

### 4. Check for Common Issues
- Unhandled error paths
- Missing input validation at system boundaries
- Breaking changes without migration notes
- Dead code or debugging artifacts left behind
- Inconsistency with existing codebase patterns

## Output Format

### PR Summary
Brief description of what the PR does and its scope.

### Critical Issues (must fix before merge)
Issues that would cause bugs, security vulnerabilities, or data loss.

### Warnings (should fix)
Issues that could cause problems but aren't blocking.

### Suggestions (nice to have)
Improvements for readability, performance, or maintainability.

### Verdict
- **Approve**: No critical issues, ready to merge
- **Request Changes**: Critical issues found, list what needs fixing
- **Comment**: Questions or suggestions, no blocking issues

For each finding:
- File and line reference
- What the issue is
- Why it matters
- Suggested fix (with code if helpful)

Be constructive and specific. Praise good patterns when you see them.
