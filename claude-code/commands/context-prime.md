---
description: Initialize session with comprehensive project context
allowed-tools: Read, Bash(git log:*), Bash(git status:*), Bash(git branch:*), Bash(git remote:*), Grep, Glob
---

You are priming the conversation with project context for effective collaboration.

## Context Loading Process

1. **Project Structure**:
   ```bash
   # Show directory structure
   find . -type f -name "*.md" -o -name "package.json" -o -name "*.toml" | head -20
   tree -L 2 -I 'node_modules|.git' 2>/dev/null || ls -R | head -50
   ```

2. **Technology Stack**:
   - Detect from files:
     - `package.json` → Node.js/JavaScript/TypeScript
     - `requirements.txt` / `pyproject.toml` → Python
     - `Cargo.toml` → Rust
     - `go.mod` → Go
     - `Gemfile` → Ruby

3. **Project Documentation**:
   - Read `README.md`
   - Read `CLAUDE.md` if exists
   - Check `docs/` directory

4. **Recent Activity**:
   ```bash
   git log -5 --oneline
   git status
   ```

5. **Current State**:
   - Open issues or TODOs
   - Recent changes
   - Active branches

## Output Format

```markdown
## Project Context Loaded

### Project: [Name]
[Brief description from README]

### Tech Stack
- Language: [detected]
- Framework: [detected]
- Database: [if applicable]
- Build tool: [detected]

### Project Structure
\`\`\`
[Key directories and their purposes]
\`\`\`

### Recent Activity
- Last 5 commits
- Current branch: [name]
- Uncommitted changes: [yes/no]

### Development Guidelines
[From CLAUDE.md or README]

---

**Context primed. Ready to work on this project.**
```

Ask: "What would you like to work on?"
