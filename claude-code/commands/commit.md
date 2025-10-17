---
description: Smart git commit with conventional commit messages
argument-hint: [optional message]
allowed-tools: Bash(git:*), Read, Grep
---

You are creating a git commit with a conventional commit message.

## Process

1. **Analyze changes**:
   ```bash
   git status
   git diff --staged
   ```

2. **Determine commit type**:
   - `feat`: New feature
   - `fix`: Bug fix
   - `docs`: Documentation changes
   - `style`: Code style/formatting (no logic changes)
   - `refactor`: Code restructuring (no behavior change)
   - `perf`: Performance improvements
   - `test`: Adding or updating tests
   - `build`: Build system or dependencies
   - `ci`: CI configuration changes
   - `chore`: Other changes (maintenance)

3. **Generate conventional commit message**:
   ```
   <type>(<scope>): <description>

   [optional body]

   [optional footer]
   ```

4. **Create commit**:
   ```bash
   git commit -m "generated message"
   ```

## Guidelines

- Keep subject line under 72 characters
- Use imperative mood ("add" not "added")
- Don't end subject with period
- Body explains "what" and "why", not "how"
- Reference issues in footer: "Closes #123"

## If $ARGUMENTS provided

Use `$ARGUMENTS` as the commit message directly (but still validate it follows conventional commits format).

## Output

Show the commit message before creating it and confirm it's appropriate.
