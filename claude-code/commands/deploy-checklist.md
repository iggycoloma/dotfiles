---
description: Pre-deployment verification checklist
allowed-tools: Read, Bash, Grep, Glob
---

You are verifying the system is ready for deployment.

## Deployment Checklist

### 1. Code Quality
- [ ] All tests passing
  ```bash
  npm test
  ```
- [ ] Linter passes with no errors
  ```bash
  npm run lint
  ```
- [ ] Build succeeds
  ```bash
  npm run build
  ```
- [ ] No console.log or debug statements
  ```bash
  grep -r "console.log\|debugger" src/
  ```

### 2. Security
- [ ] No hardcoded secrets
  ```bash
  grep -r "api_key\|password\|secret" src/
  ```
- [ ] Dependencies have no critical vulnerabilities
  ```bash
  npm audit
  ```
- [ ] Environment variables configured correctly
- [ ] HTTPS enabled

### 3. Performance
- [ ] Load testing completed (if major changes)
- [ ] Database queries optimized
- [ ] Caching configured
- [ ] Asset compression enabled

### 4. Database
- [ ] Migrations tested on staging
- [ ] Rollback plan prepared
- [ ] Backups verified
- [ ] Indexes created where needed

### 5. Documentation
- [ ] README up to date
- [ ] CHANGELOG entry added
- [ ] API docs current
- [ ] Deployment runbook exists

### 6. Monitoring & Logging
- [ ] Error tracking configured (Sentry, etc.)
- [ ] Logging enabled
- [ ] Health check endpoint working
- [ ] Alerts configured

### 7. Staging Verification
- [ ] Deployed to staging successfully
- [ ] Smoke tests passed on staging
- [ ] Manual testing completed
- [ ] No errors in logs

### 8. Rollback Plan
- [ ] Previous version tagged
- [ ] Rollback procedure documented
- [ ] Database migrations reversible
- [ ] Know how to revert quickly

### 9. Communication
- [ ] Stakeholders notified
- [ ] Maintenance window scheduled (if needed)
- [ ] Changelog shared with team
- [ ] Support team briefed

### 10. Post-Deployment
- [ ] Monitor error rates (first 30 minutes)
- [ ] Check performance metrics
- [ ] Verify critical user flows
- [ ] Watch for anomalies

## Output

Generate checklist report:

### ✅ Passed (N items)
- List items that passed

### ⚠️ Warnings (N items)
- List items with warnings

### ❌ Blockers (N items)
- List items that must be fixed before deployment

**Deployment Status**: READY / NOT READY / READY WITH WARNINGS

If blockers exist, DO NOT deploy. Fix them first.
