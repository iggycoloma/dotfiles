---
description: Analyze performance and suggest optimizations
argument-hint: [file or function to optimize]
---

You are analyzing code for performance improvements.

## What to Optimize

If `$ARGUMENTS` provided:
- Analyze the specified file or function

If no arguments:
- Ask user what's slow or needs optimization

## Analysis Process

1. **Measure First**:
   - What is the current performance?
   - Where is the bottleneck?
   - Use profiling tools if available

2. **Identify Issues**:
   - Algorithm complexity (O(n²) loops?)
   - Inefficient data structures
   - Unnecessary computations
   - Database query problems (N+1 queries?)
   - Memory leaks or excessive allocation

3. **Propose Optimizations**:
   Prioritize by impact vs effort:
   - **Quick wins**: High impact, low effort
   - **Major improvements**: High impact, high effort
   - **Nice to have**: Low impact, low effort

## Common Performance Issues

### Algorithm Complexity
```javascript
// Before: O(n²) - nested loops
for (const item of list1) {
  for (const other of list2) {
    if (item.id === other.id) { }
  }
}

// After: O(n) - use Map for O(1) lookups
const map = new Map(list2.map(item => [item.id, item]));
for (const item of list1) {
  const match = map.get(item.id);
}
```

### Caching
```javascript
// Before: Recalculate every time
function expensiveCalc(input) {
  return /* expensive operation */;
}

// After: Cache results
const cache = new Map();
function expensiveCalc(input) {
  if (cache.has(input)) return cache.get(input);
  const result = /* expensive operation */;
  cache.set(input, result);
  return result;
}
```

### Database Optimization
```sql
-- Before: N+1 queries
SELECT * FROM users;
-- Then N queries: SELECT * FROM orders WHERE user_id = ?

-- After: Single query with join
SELECT users.*, orders.*
FROM users LEFT JOIN orders ON orders.user_id = users.id;
```

## Output Format

### Current Performance
- Baseline metrics (if available)

### Bottlenecks Identified
1. Issue description
2. Impact assessment
3. Location in code

### Optimization Plan
1. Quick wins (do these first)
2. Major improvements
3. Nice to have

### Expected Improvements
- Estimated performance gain
- Implementation effort

Provide specific code examples. Measure improvements after implementation.
