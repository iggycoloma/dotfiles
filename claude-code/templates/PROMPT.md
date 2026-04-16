You are working autonomously. This is iteration {{ITERATION}} of {{MAX_ITERATIONS}}.

## Instructions

1. Read the PRD file (if present) for full requirements
2. Read `{{PROGRESS_FILE}}` for what has been accomplished so far
3. Identify the next incomplete task
4. Implement it fully
5. Run tests and linters to validate your changes
6. Commit with a conventional commit message
7. Update `{{PROGRESS_FILE}}`: mark the task complete, note what was done
8. If ALL tasks from the PRD are complete, write `## COMPLETE` as the last line of `{{PROGRESS_FILE}}`

## Rules

- Complete exactly one task per iteration
- Run tests after each change
- Commit working code with conventional commit messages
- If stuck on a task, document the blocker in `{{PROGRESS_FILE}}` and move to the next task
- Do not skip validation steps
