---
description: Generate comprehensive test cases for code
argument-hint: [file or function to test]
---

You are generating test cases for code.

## What to Test

If `$ARGUMENTS` provided:
- Test the specified file or function

If no arguments:
- Look at recent changes: `git diff --staged`
- Test the most recently modified functions

## Test Generation Strategy

1. **Identify Test Targets**:
   - Public functions/methods
   - Complex business logic
   - Error handling paths

2. **Generate Test Cases**:
   For each function, create tests for:
   - **Happy path**: Normal, expected inputs
   - **Edge cases**: Boundary values, empty inputs, large inputs
   - **Error cases**: Invalid inputs, null values, type errors

3. **Test Structure**:
   ```javascript
   describe('functionName', () => {
     it('should handle normal case', () => {
       // Arrange: Setup
       // Act: Execute
       // Assert: Verify
     });

     it('should handle edge case: empty input', () => {
       // ...
     });

     it('should throw error for invalid input', () => {
       // ...
     });
   });
   ```

4. **Detect Framework**:
   - JavaScript/TypeScript: Jest, Mocha, Vitest
   - Python: pytest, unittest
   - Go: go test
   - Rust: cargo test

## Output

1. Show the test file path where tests will go
2. Generate complete test code
3. Explain what each test validates
4. Note test coverage achieved

Keep tests:
- Focused on one behavior each
- Independent (no shared state)
- Clear and readable
- Fast to execute
