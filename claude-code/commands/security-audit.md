---
description: Comprehensive security vulnerability scan
argument-hint: [directory to audit]
---

You are performing a security audit.

## Scope

If `$ARGUMENTS` provided:
- Audit the specified directory

If no arguments:
- Audit the entire project

## Security Checklist

### 1. Secrets & Credentials
```bash
# Check for exposed secrets
grep -r "api_key\|API_KEY\|password\|PASSWORD\|secret" --include="*.js" --include="*.py" --include="*.go"
```
- [ ] No hardcoded API keys
- [ ] No passwords in code
- [ ] No secrets in git history
- [ ] Environment variables used properly

### 2. Dependencies
```bash
# Check for vulnerabilities
npm audit  # Node.js
pip-audit  # Python
cargo audit  # Rust
```
- [ ] No known CVEs
- [ ] Dependencies up-to-date
- [ ] No malicious packages

### 3. Input Validation
- [ ] All user input validated
- [ ] SQL injection prevented (parameterized queries)
- [ ] XSS prevented (output escaping)
- [ ] Command injection prevented

### 4. Authentication & Authorization
- [ ] Strong authentication (MFA supported)
- [ ] Secure session management
- [ ] Proper authorization checks
- [ ] Password hashing (bcrypt/argon2)

### 5. Data Protection
- [ ] Sensitive data encrypted at rest
- [ ] HTTPS/TLS for data in transit
- [ ] PII handled appropriately
- [ ] Secure random number generation

### 6. Common Vulnerabilities (OWASP Top 10)
- [ ] Broken access control
- [ ] Cryptographic failures
- [ ] Injection vulnerabilities
- [ ] Insecure design
- [ ] Security misconfiguration
- [ ] Vulnerable components
- [ ] Authentication failures
- [ ] Data integrity failures
- [ ] Logging failures
- [ ] SSRF vulnerabilities

## Output Format

### 🔴 Critical (Fix Immediately)
List critical security issues

### 🟠 High (Fix Before Release)
List high priority issues

### 🟡 Medium (Address Soon)
List medium priority issues

### 🟢 Low (Consider)
List low priority improvements

For each issue:
- Location and description
- Potential impact
- Recommended fix

Be thorough but pragmatic. Focus on real risks.
