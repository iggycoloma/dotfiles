# Contract: Claude Code Hook Protocol

The dotfiles hooks (`pre-security.sh`, `pre-code-no-emoji.sh`, `post-scope-audit.sh`, `post-dep-audit.sh`, `notify.sh`, `session-start-banner.sh`) all conform to Claude Code's documented hook protocol.
This contract documents the relevant subset.

Note: an earlier `pre-commit-validate.sh` PreToolUse hook was deprecated and removed.
Commit-message validation now lives only in the global git `commit-msg` hook (wired via `core.hooksPath`).
The single source of truth is the git hook; the PreToolUse hook was a duplicate that drifted in practice.

## Hook event types

| Event           | Tool matchers (in this repo)                                          |
|-----------------|-----------------------------------------------------------------------|
| `PreToolUse`    | `Read \| Write \| Edit`, `Bash`, `Write \| Edit`                      |
| `PostToolUse`   | `Write \| Edit`, `Bash`                                               |
| `Notification`  | `idle_prompt`                                                         |
| `SessionStart`  | (no matcher; fires on every new session)                              |

## Input contract (stdin)

Every hook receives a single JSON object on stdin.
Relevant fields:

```json
{
  "tool_name": "Read" | "Write" | "Edit" | "Bash" | ...,
  "tool_input": {
    "file_path": "/abs/path/to/file",     // for Read/Write/Edit
    "command": "git status -sb"            // for Bash
  },
  "session_id": "01H...",
  "transcript_id": "01H..."
}
```

The hooks parse this with `jq -r '.tool_name // empty'` and `jq -r '.tool_input.file_path // empty'` etc. `jq` is mandatory; hooks exit with `Error: jq is required for this hook` to stderr if missing.

## Output contract (stdout)

PreToolUse hooks emit a single JSON object on stdout to influence the permission decision:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow" | "ask" | "deny",
    "permissionDecisionReason": "human-readable string"
  }
}
```

If the hook emits no output and exits 0, the framework defaults to `allow`.
Non-zero exit is a hard failure (hook misconfigured) and defaults to `deny` (fail closed).

## Decision semantics

| Decision  | Effect                                                                   |
|-----------|--------------------------------------------------------------------------|
| `allow`   | Tool call proceeds without further user prompt                           |
| `ask`     | User is prompted; sees `permissionDecisionReason`                        |
| `deny`    | Tool call is rejected with the reason as the tool error                  |

## Hook-specific behavior in this repo

### `pre-security.sh`

- For `Bash`: scans the command string against three lists: `SENSITIVE_PATHS` (file substrings like `*/.env`), `SENSITIVE_DIRS` (directory references like `.ssh/`, `.aws/`), `SENSITIVE_FILES` (standalone files like `.npmrc`).
- For `Read|Write|Edit`: glob-matches `file_path` against `SENSITIVE_PATHS` and `SENSITIVE_EXTENSIONS` (`*.pem`, `*.key`, etc.); also returns `deny` for path traversal (`../`).
- Emits `ask` for matches; framework default `allow` for non-matches.

### `pre-code-no-emoji.sh`

- Triggered on Write/Edit.
- Reads `tool_input.content` (Write) or `tool_input.new_string` (Edit), scans for Unicode emoji characters, returns `deny` if found.

### `notify.sh`

- Triggered on Notification with matcher `idle_prompt`.
- No permission decision (Notification hooks have no output contract for permissions).
- Side effect: HTTP POST to Pushover API if `PUSHOVER_TOKEN` and `PUSHOVER_USER` are set; silent no-op otherwise.

### `session-start-banner.sh`

- Triggered on SessionStart.
- Output goes to the model's system reminder context (not the permission machinery).

## Versioning

This contract is locked to the current Claude Code hook event format (documented at `https://docs.anthropic.com/en/docs/claude-code/hooks`).
If Anthropic changes the contract:
1. Update this file.
2. Update every hook script.
3. Update `tests/test-security-hook.sh` to exercise the new shape.
4. Bump the `006-claude-code-config` plan's Constitution Check note.
