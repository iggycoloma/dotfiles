---
description: Check and update project dependencies
---

You are managing project dependencies.

## Process

1. **Detect Package Manager**:
   - Node.js: npm, yarn, pnpm (check for package.json)
   - Python: pip, poetry (check for requirements.txt, pyproject.toml)
   - Go: go modules (check for go.mod)
   - Rust: cargo (check for Cargo.toml)

2. **Check for Updates**:
   ```bash
   # Node.js
   npm outdated
   npm audit

   # Python
   pip list --outdated
   pip-audit

   # Go
   go list -u -m all

   # Rust
   cargo outdated
   ```

3. **Security Scan**:
   ```bash
   # Node.js
   npm audit
   npm audit fix

   # Python
   pip-audit
   safety check

   # Rust
   cargo audit
   ```

4. **Categorize Updates**:
   - **Critical**: Security vulnerabilities (update immediately)
   - **Patch**: Bug fixes (low risk, update soon)
   - **Minor**: New features (test thoroughly)
   - **Major**: Breaking changes (plan carefully)

## Output Format

### Security Vulnerabilities
🔴 **Critical**: List with CVE numbers
🟡 **Medium**: List with impact

### Available Updates
**Patch Updates** (Low Risk):
- package-name: 1.2.3 → 1.2.4

**Minor Updates** (Test Recommended):
- package-name: 1.2.0 → 1.3.0

**Major Updates** (Breaking Changes):
- package-name: 1.x.x → 2.0.0
  - [Link to migration guide]

### Recommendations
1. Update security vulnerabilities immediately
2. Apply patch updates (safe)
3. Schedule testing for minor updates
4. Plan migration for major updates

### Commands to Run
```bash
# Update specific packages
npm install package-name@latest

# Or update all patches
npm update
```

Always run tests after updates!
