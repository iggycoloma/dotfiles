---
name: generate-changelog
description: Generate a user-facing Keep a Changelog entry from a named revision range or commits since the latest tag. Use when the user asks to draft or update release notes or a changelog.
---

You are generating a changelog entry.

## Process

1. **Get Commits**:
   ```bash
   # If the user provided from/to revisions
   git log <from>..<to> --oneline --no-merges

   # If no revisions were provided, resolve the latest tag first, then use
   # that literal tag in a separate git log command.
   git describe --tags --abbrev=0
   git log <latest-tag>..HEAD --oneline --no-merges
   ```

2. **Categorize Commits**:
   Based on conventional commit types:
   - **Added**: New features (`feat:`)
   - **Changed**: Changes in existing functionality
   - **Deprecated**: Soon-to-be removed features
   - **Removed**: Removed features
   - **Fixed**: Bug fixes (`fix:`)
   - **Security**: Security fixes

3. **Format as Keep a Changelog**:
   ```markdown
   ## [Version] - YYYY-MM-DD

   ### Added
   - New feature description [#123]

   ### Changed
   - Modified behavior description

   ### Fixed
   - Bug fix description [#456]

   ### Security
   - Security fix description
   ```

4. **Include Details**:
   - User-facing changes only
   - Link to issues/PRs
   - Note breaking changes prominently
   - Group related changes

## Output

Generate changelog entry ready to paste into CHANGELOG.md.

Follow [Keep a Changelog](https://keepachangelog.com) format.
