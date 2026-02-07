---
description: Generate comprehensive feature specification
argument-hint: <feature-name>
allowed-tools: Read, Write, Grep, Glob
---

You are creating a detailed feature specification.

## Feature Name

Use `$ARGUMENTS` as the feature name.

## Specification Template

### 1. Overview
- What is this feature?
- Why are we building it?
- Who is it for?

### 2. User Stories

Format: "As a [user type], I want to [action], so that [benefit]"

Example:
```markdown
#### Story 1: User Registration
**As a** new user
**I want** to create an account with email and password
**So that** I can access personalized features

**Acceptance Criteria:**
- [ ] User can enter email and password
- [ ] Email is validated for format
- [ ] Password meets security requirements (8+ chars, mixed case, number)
- [ ] Confirmation email is sent
- [ ] User is redirected to dashboard after signup
```

### 3. Functional Requirements

What must the feature do?
- Requirement 1
- Requirement 2
- Requirement 3

### 4. Non-Functional Requirements

- **Performance**: Response time < 200ms
- **Security**: Data encrypted, HTTPS required
- **Scalability**: Support 10k concurrent users
- **Accessibility**: WCAG 2.1 AA compliant

### 5. User Flow

```
1. User navigates to [page]
2. User clicks [button]
3. System displays [form/modal]
4. User enters [data]
5. System validates [data]
6. System saves [data]
7. User sees [confirmation]
```

### 6. Edge Cases

What could go wrong?
- Scenario 1: [Description] → Expected behavior
- Scenario 2: [Description] → Expected behavior

### 7. API Endpoints (if applicable)

```
POST /api/feature
Request: { data }
Response: { result }
Errors: 400, 401, 500
```

### 8. Data Model (if applicable)

```sql
CREATE TABLE feature_data (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id),
  data JSONB,
  created_at TIMESTAMP
);
```

### 9. Dependencies

- Requires: [Existing features/services]
- Blocks: [Features waiting on this]
- Integrates with: [External services]

### 10. Success Metrics

How do we measure success?
- Metric 1: Target value
- Metric 2: Target value

### 11. Out of Scope

What we're NOT doing:
- Feature X (future phase)
- Feature Y (different team)

## Output

Generate complete specification document and save to `.claude/specs/$ARGUMENTS.md`

Ask clarifying questions if needed before finalizing.
