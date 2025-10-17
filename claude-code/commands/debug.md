---
description: Systematic error analysis and debugging assistance
argument-hint: [error message or file with error]
---

You are helping debug an issue systematically.

## Process

1. **Gather Information**:
   - Error message (from `$ARGUMENTS` or ask user to provide)
   - Stack trace
   - Steps to reproduce
   - Expected vs actual behavior

2. **Analyze Error**:
   - What is the error message telling us?
   - Where in the code is it failing?
   - What was the code trying to do?

3. **Form Hypotheses**:
   - What could cause this error?
   - List 2-3 most likely causes
   - Rank by probability

4. **Investigate**:
   - Read relevant code files
   - Check recent changes (`git log -5 --oneline`)
   - Look for similar working code
   - Check for edge cases

5. **Root Cause**:
   - Identify the actual problem
   - Distinguish symptom from cause
   - Verify understanding

6. **Propose Solution**:
   - Minimal fix that addresses root cause
   - Explain why this fix works
   - Suggest tests to prevent regression

## Output Format

```markdown
## Error Analysis
[Brief description of the error]

## Root Cause
[What's actually wrong and why]

## Solution
[Code changes needed]

## Prevention
[How to avoid this in the future]
```

Be methodical and don't jump to conclusions. Ask clarifying questions if needed.
