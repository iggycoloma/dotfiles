# Agent Skill metadata

Reference for the `SKILL.md` contract across the harnesses this repo deploys to.
Read it before adding a skill to `agent-skills/` or changing how an existing one is invoked.

`agent-skills/` follows the open [Agent Skills](https://agentskills.io) format, originally developed by Anthropic and now adopted across agent products:
a directory holding `SKILL.md` (YAML frontmatter plus instructions), optionally `scripts/`, `references/`, `assets/`, and product-specific config.
Agents load it by progressive disclosure -- name and description at startup, the body only when the skill fires -- so a long skill costs almost nothing until it is used.

Six frontmatter fields are portable across every consumer:
`name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`.
Everything past them is harness-specific.
Claude Code accepts all six plus its own extensions and ignores fields it does not know; claude.ai uploads, the Skills API, and `package_skill.py` hard-error on any seventh field.

**Claude Code frontmatter.** All optional; `description` is what drives automatic invocation.

| Field | Purpose |
|-------|---------|
| `name` | Display name; defaults to the directory name |
| `description`, `when_to_use` | Trigger text; concatenated and truncated at 1,536 chars in the skill listing |
| `disable-model-invocation` | `true` stops Claude loading it on its own; also blocks subagent preload and scheduled-task firing |
| `user-invocable` | `false` hides it from the `/` menu, for skills only Claude should reach |
| `allowed-tools`, `disallowed-tools` | Grant or withdraw tools for the invoking turn only |
| `argument-hint`, `arguments` | Autocomplete hint; named positional arguments for `$name` substitution |
| `model`, `effort` | Override model or effort while the skill is active |
| `context: fork`, `agent`, `background` | Run in a forked subagent, which type, awaited or backgrounded |
| `paths` | Globs that gate automatic activation |
| `hooks` | Hooks registered when the skill is invoked, kept for the session |
| `shell` | `bash` (default) or `powershell` for inline command blocks |
| `version`, `created_by`, `improved_by` | Provenance; accepted, not acted on |

**Codex `agents/openai.yaml`.** An optional sidecar read by the harness rather than the model, and the format's slot for product-specific config.
Quote string values; leave keys unquoted.

| Key | Purpose |
|-----|---------|
| `policy.allow_implicit_invocation` | Defaults `true`; `false` keeps the skill out of the model's context, reachable only as `$skill-name` |
| `interface.display_name` | Title shown in skill lists and chips |
| `interface.short_description` | 25-64 character UI blurb |
| `interface.icon_small`, `interface.icon_large` | Asset paths relative to the skill directory |
| `interface.brand_color` | Hex accent colour |
| `interface.default_prompt` | Invocation snippet; must name the skill as `$skill-name` |
| `dependencies.tools[]` | `type` (only `mcp` today), `value`, `description`, `transport`, `url` |

**A manual-only skill sets both.**
The harnesses do not share a spelling: Claude Code honors only `disable-model-invocation: true`, Codex honors only `policy.allow_implicit_invocation: false`, and each ignores the other's.
Setting one leaves the skill silently model-invocable in the other, so `tests/test-consistency.sh` asserts the pair.
Two consequences to weigh first: Claude Code will not run such a skill in coordinator mode, and Codex plugin validation rejects `disable-model-invocation: true` outright, so the skill cannot ship inside a Codex plugin unchanged.

**Sources.**
Format: <https://agentskills.io>, specification at `/specification`.
Claude Code: <https://code.claude.com/docs/en/skills>.
Codex: <https://learn.chatgpt.com/docs/build-skills>.
Codex also embeds its own `skill-creator` reference; recover it with
`strings "$(readlink -f "$(command -v codex)")" | grep -n openai_yaml`.
Confirm what Codex actually exposes to the model with `codex debug prompt-input`.
