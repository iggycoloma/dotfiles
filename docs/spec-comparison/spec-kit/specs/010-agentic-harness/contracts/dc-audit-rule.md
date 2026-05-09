# Contract: dc-audit Rule

## Authoritative location

`agentic/devcontainer-rubric.json` -- one entry per rule under
`rules.<rule-id>`.

## Rule schema

```typescript
interface Rule {
  id: string;                       // kebab-case stable id
  severity: "info" | "warn" | "error";
  description: string;              // human-readable
  applies_to: string[];             // JSONPath-like selectors against devcontainer.json
  check: CheckPredicate;
  check_args: object;               // predicate-specific
  fix_expression: string | null;    // jq expression; null = no auto-fix
  tags: string[];                   // free-form filter tags
}

type CheckPredicate =
  | "contains"          // applies_to value contains check_args.substring
  | "pattern_match"     // applies_to value matches check_args.regex
  | "forbids_pattern"   // applies_to value MUST NOT match check_args.regex
  | "is_pinned"         // applies_to value is a pinned reference (digest, exact tag, etc.)
  | "array_contains_all";  // applies_to is an array containing every element of check_args.values
```

## Predicate semantics

### `contains`
```json
{ "check": "contains", "check_args": { "substring": "no-new-privileges" } }
```
Passes if any value in `applies_to` (which may be an array) contains
the substring.

### `pattern_match`
```json
{ "check": "pattern_match", "check_args": { "regex": "^\\d+m$" } }
```
Passes if the value matches the regex (PCRE).

### `forbids_pattern`
```json
{ "check": "forbids_pattern", "check_args": { "regex": "/var/run/docker.sock" } }
```
Passes if NO value matches the regex. Used for negative checks
(e.g. "must not bind-mount the docker socket in unattended profile").

### `is_pinned`
```json
{ "check": "is_pinned", "check_args": { "kind": "image" } }
```
For images: passes if the reference includes a digest (`@sha256:...`)
or a non-`latest` tag with a version-like string (`:1.2.3`,
`:ubuntu-24.04`).

### `array_contains_all`
```json
{ "check": "array_contains_all", "check_args": { "values": ["--security-opt=no-new-privileges", "--cap-drop=ALL"] } }
```
Passes if `applies_to` is an array AND every element of `check_args.values`
is present.

## Output contract (JSONL)

When `--json` is set, dc-audit emits one JSON object per finding:

```json
{
  "rule_id": "no-new-privileges",
  "severity": "warn",
  "file": ".devcontainer/foo/devcontainer.json",
  "applies_to": "runArgs",
  "message": "runArgs must include --security-opt=no-new-privileges",
  "fixable": true,
  "fix_applied": false
}
```

When `--fix` is also set, `fix_applied: true` if the auto-fix was
applied successfully; `fix_applied: false` with an `error` field if
the jq expression failed.

## Exit codes

- `0` -- no findings, OR findings but not in `--strict` mode.
- `1` -- findings of severity `warn` or `error` exist AND `--strict`
  was passed.
- `2` -- usage error (bad flags, missing file).
- `3` -- rubric file malformed (cannot parse).

## Adding a new rule

1. Add the rule entry under `rules.<rule-id>` in
   `agentic/devcontainer-rubric.json`.
2. Add the rule's `id` to one or both profiles under `profiles`.
3. Add a positive and a negative test case to `tests/test-dc-audit.sh`.
4. If the rule has a `fix_expression`, add a test verifying the fix
   is purely additive.
5. Document the rule's intent in `agentic/README.md` or a sub-doc if
   the rationale is non-obvious.

## Compatibility commitment

The schema's stable surface (above) does not change without a
rubric `version` bump. Adding new optional fields is a minor bump
(1.0 -> 1.1); changing an existing field's semantics is a major
bump (1.0 -> 2.0) and dc-audit refuses to load a rubric of an
unsupported major version.
