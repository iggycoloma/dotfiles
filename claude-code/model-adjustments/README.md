# Model adjustments

Per-model instruction fragments, injected at session start by `hooks/model-context.sh` so that corrections for one model's known biases never load into sessions running a different model.
Claude-only by construction: the mechanism keys on Claude Code's `model` hook field and Anthropic model ids, so it lives here rather than in `agent-prompts/`.

## How it works

- `SessionStart` is the only hook event whose input carries the session's model id, as an optional `model` field.
- `model-context.sh` strips the `claude-` prefix from that id, then drops trailing `-` components until a filename in this directory matches: model `claude-opus-5-20260101` tries `opus-5-20260101.md`, then `opus-5.md`, then `opus.md`.
- The first match is printed to stdout, which Claude Code adds to the session's context.
  No `model` field, no `jq`, or no matching file means no output -- the hook fails open, because a missing style fragment is not worth blocking a session over.

## Adding a model

Create `<key>.md` where `<key>` is the model id without the `claude-` prefix, at whatever specificity you want:
`opus-5.md` covers every Opus 5 point release unless a more specific file (say `opus-5-1.md`) exists, and `opus.md` would cover the whole family.
Deployment is directory-level via `_deploy_configs` in `bootstrap/symlinks.sh`, so a new fragment needs no manifest entry -- rerun `install.sh` (or `bootstrap/symlinks.sh`) after adding one.

Keep fragments short: a fragment is always-on context for every session on its model.
State observed biases and the correction; sharpen the global rules in `agent-prompts/writing-style.md`, never contradict them.

## Limitations

- A mid-session `/model` switch is invisible: no hook event fires on model change, so the fragment loaded at start stays in effect for the session.
- The `model` field is documented as optional; when absent, no adjustments load.
- Matching assumes plain Anthropic ids (`claude-*`). Bedrock/Vertex-style ids (`us.anthropic.claude-...`) would need the prefix handling extended.
