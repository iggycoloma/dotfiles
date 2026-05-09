# /constitution

Create or amend `.specify/memory/constitution.md`. Drives a Sync Impact Report
listing every artifact that needs to be re-validated against the new
constitution.

## Inputs
- `.specify/memory/constitution.md` -- existing constitution (if any).
- `.specify/templates/constitution-template.md` -- bracketed template if
  starting fresh.
- User input -- the principles, rules, or amendments to apply.

## Workflow

1. **Load existing constitution.** Identify `[BRACKETED_TOKENS]` if first-run.
2. **Collect or derive values.** From user input + repo context (existing
   tech stack, patterns, conventions).
3. **Draft updated content.** Replace placeholders. Each principle gets:
   - Name (`### Article N: <Name>`).
   - Rules (numbered or bulleted).
   - Rationale (why this principle exists).
4. **Validate consistency** across dependent templates:
   - `plan-template.md` Constitution Check section -- references each article
     by name.
   - `spec-template.md` -- terminology aligned with constitution wording.
   - `tasks-template.md` -- task IDs and phase names consistent.
5. **Generate Sync Impact Report**:
   - Version bump (MAJOR / MINOR / PATCH per the rules below).
   - Modified articles, added articles, removed articles.
   - Downstream artifacts that may need re-validation against the new
     constitution.
6. **Validate output**:
   - No unexplained `[BRACKETED]` tokens remain.
   - `Ratification Date` present (set on first creation, never changed).
   - `Last Amended Date` updated to today (ISO 8601).
   - `Version` bumped per rules.
7. **Write** `.specify/memory/constitution.md`.
8. **Output** the Sync Impact Report and a summary of the version bump
   rationale.

## Versioning Rules

- **MAJOR** -- removing or fundamentally changing an article (e.g., dropping
  cross-platform parity).
- **MINOR** -- adding an article or expanding scope of an existing one.
- **PATCH** -- clarifying language without changing meaning.

## Output

- `.specify/memory/constitution.md` (created or modified).
- Sync Impact Report in stdout (and ideally pasted into the PR description).

## Constraints
- Articles are non-negotiable in plan.md's Constitution Check, so wording
  matters. Avoid weasel words ("appropriate", "reasonable", "as needed").
- Each article must be testable. "Code should be clean" fails this; "Shell
  scripts must be shellcheck-clean before merge" passes.
- The constitution is the contract that gates everything downstream. Treat
  amendments with the gravity of breaking-API changes.
