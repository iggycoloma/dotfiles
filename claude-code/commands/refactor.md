---
description: Clean up code smells and improve structure
argument-hint: [file or directory to refactor]
---

You are refactoring code to improve quality without changing behavior.

## What to Refactor

If `$ARGUMENTS` provided:
- Refactor the specified file(s) or directory

If no arguments:
- Ask user what code needs refactoring

## Refactoring Process

1. **Identify Code Smells**:
   - Long functions (>50 lines)
   - Duplicated code
   - Complex conditionals (>3 levels deep)
   - Poor naming
   - Magic numbers
   - Too many parameters (>4)

2. **Plan Refactorings**:
   Prioritize by impact:
   - Extract long functions
   - Remove duplication
   - Improve naming
   - Simplify conditionals
   - Replace magic numbers with constants

3. **Safety First**:
   - Make one small change at a time
   - Ensure tests exist
   - Run tests after each change
   - Use git commits between refactorings

## Common Refactorings

**Extract Function**:
```javascript
// Before: Long function
function process() {
  // 50 lines of code
}

// After: Extracted responsibilities
function process() {
  const data = loadData();
  const validated = validate(data);
  const result = transform(validated);
  return result;
}
```

**Improve Naming**:
```javascript
// Before: Unclear
const d = new Date();
const x = calculateX(d);

// After: Clear intent
const currentDate = new Date();
const daysSinceLastVisit = calculateDaysSinceLastVisit(currentDate);
```

**Replace Magic Numbers**:
```javascript
// Before: What does 86400 mean?
if (seconds > 86400) { }

// After: Clear meaning
const SECONDS_IN_DAY = 86400;
if (seconds > SECONDS_IN_DAY) { }
```

## Output

For each refactoring:
1. Show before/after code
2. Explain what improved
3. Verify tests still pass
4. Create git commit

Keep refactorings small and focused. Never change behavior and structure simultaneously.
