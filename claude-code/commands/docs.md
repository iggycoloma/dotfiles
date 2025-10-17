---
description: Update documentation to match code changes
argument-hint: [files to document]
---

You are updating documentation to stay in sync with code.

## What to Document

If `$ARGUMENTS` provided:
- Document the specified files

If no arguments:
- Check recent changes: `git diff --staged` or `git log -1 --stat`
- Update docs affected by those changes

## Documentation Types

### README.md
- Project overview
- Installation instructions
- Quick start guide
- Usage examples
- Configuration options

### API Documentation
- Function/method signatures
- Parameters and return values
- Example requests/responses
- Error codes

### Code Comments
- Docstrings for public functions
- Complex algorithm explanations
- Edge case notes
- TODOs and FIXMEs

### CHANGELOG.md
- Follow Keep a Changelog format
- Document breaking changes
- Note deprecations

## Process

1. **Identify Changes**:
   - What code changed?
   - What functionality was added/modified?
   - Are there breaking changes?

2. **Find Affected Docs**:
   - README sections
   - API documentation files
   - Inline comments
   - CHANGELOG entries

3. **Update Documentation**:
   - Ensure accuracy with current code
   - Add examples where helpful
   - Note any breaking changes clearly
   - Update version numbers if needed

4. **Verify**:
   - Code examples actually work
   - Links aren't broken
   - Formatting is correct

## Output

List files updated:
- `README.md` - Added XYZ section
- `docs/api.md` - Updated endpoint documentation
- `CHANGELOG.md` - Added v1.2.0 entry

Keep documentation clear, concise, and accurate.
