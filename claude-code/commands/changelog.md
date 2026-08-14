---
description: Generate changelog from recent commits
argument-hint: "[from-tag] [to-tag]"
allowed-tools: Read, Bash(git log:*), Bash(git describe:*), Bash(git tag:*), Grep
---

You are generating a changelog entry.

## Process

1. **Get Commits**:
   ```bash
   # If arguments provided (from-tag to-tag)
   git log $1..$2 --oneline --no-merges

   # If no arguments, since last tag
   git log $(git describe --tags --abbrev=0)..HEAD --oneline --no-merges
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
