# Agentic tooling

How Claude Code, Codex CLI, and Copilot CLI are integrated. For the sandbox
posture (host vs container, egress, signing), see [`sandbox.md`](sandbox.md).
For the autonomous-loop harness (`ralph.sh`, unattended profile), see
[`../unattended/README.md`](../unattended/README.md).

## Installation

In devcontainers and Codespaces, Claude Code and Codex CLI are installed
automatically as **native binaries** -- no devcontainer features, no Node.js
required. On hosts, users manage their own installs (`brew install
anthropic-ai/claude/claude`, etc.); this repo just deploys configuration.

Skip both with `DOTFILES_NO_AI_TOOLS=1`.

## Instruction-file architecture

Six instruction files, partitioned by scope (project vs global) and tool:

| File                                | Scope    | Read by         | Purpose                                                       |
|-------------------------------------|----------|-----------------|---------------------------------------------------------------|
| `AGENTS.md` (root)                  | Project  | All AI tools    | Per-repo shared instructions (guardrails, tools, quality)     |
| `CLAUDE.md` (root)                  | Project  | Claude Code     | Per-repo Claude-specific instructions                         |
| `.github/copilot-instructions.md`   | Project  | GitHub Copilot  | Per-repo Copilot instructions                                 |
| `claude-code/CLAUDE.md`             | Global   | Claude Code     | Global Claude Code instructions (deployed to `~/.claude/`)    |
| `codex/AGENTS.md`                   | Global   | Codex CLI       | Global Codex instructions (deployed to `~/.codex/`)           |
| `copilot/copilot-instructions.md`   | Global   | Copilot CLI     | Global Copilot instructions (deployed to `~/.copilot/`)       |

Project-specific instructions (quality gates, installation toggles, security
model) live in root files. Global files contain only preferences and
guardrails that apply across all repositories.

There is real duplication today in the "Guardrails" / "Preferred CLI Tools" /
"MCP Servers" sections across the six files. A future PR may unify the
duplication via a templating-at-deploy-time pass; today the duplication is
acceptable because changes are infrequent and `tests/test-consistency.sh`
catches drift on the highest-stakes piece (the credential deny-list).

## Shared guardrails

Enforced across all six files:

- No emoji in code, docs, or commits.
- Conventional commits; no AI attribution or `Co-Authored-By` lines.
- Never access credential files or directories (~50 blocked patterns).
- Prefer modern CLI tools (rg, fd, sg, difft, sd, bat, scc, yq).
- `make lint` (shellcheck + drift) clean before merging; CI enforces this.

## Claude Code

Lives at `claude-code/`. Deployed to `~/.claude/`.

| Component       | Count | Purpose                                                                |
|-----------------|-------|------------------------------------------------------------------------|
| Settings files  | 2     | `settings.json` (host) and `settings.container.json` (container variant)|
| Hooks           | 4     | Security blocking, conventional commits, no-emoji, idle notification   |
| Agents          | 5     | PM spec, architect, implementer-tester, QA reviewer, code reviewer     |
| Commands        | 16    | commit, pr-create, review-pr, debug, test, refactor, pipeline, ...     |
| Status line     | 1     | Git branch/status, context usage bar, model info                       |

The **4-stage pipeline** (`/pipeline`) runs PM Spec -> Architecture Review ->
Implementation + Tests -> QA Review, with user checkpoints between stages.

Permission model: explicit allow-list of ~70 bash commands, deny-list of ~35
credential patterns, `pre-security.sh` hook validates every file
read/write/edit at runtime. The deny-list works alongside (not instead of)
the OS-level sandbox; see [sandbox.md](sandbox.md) for how the layers stack.

### Hooks deep-dive

The hook entrypoints are documented in
[`../claude-code/hooks/README.md`](../claude-code/hooks/README.md) (deployed
to `~/.claude/hooks/README.md`). Claude and Codex both use thin wrappers around
the shared implementations in `agent-hooks/`, deployed to `~/.agent-hooks/`.
Summary:

| Hook                      | Trigger          | Action                                                              |
|---------------------------|------------------|---------------------------------------------------------------------|
| `pre-security.sh`         | Read/Write/Edit/Bash | Blocks ~50 sensitive file patterns and credential directories   |
| `pre-commit-validate.sh`  | Bash (git commit)| Enforces conventional commits, blocks AI attribution                |
| `pre-code-no-emoji.sh`    | Write/Edit       | Blocks decorative emoji in code files                               |
| `notify.sh`               | Notification     | Pushover notification when Claude is idle and waiting for input     |

Exit codes: `0` = continue, `2` = block (stderr shown as denial reason).
Other non-zero codes are logged but don't block.

## Codex CLI

Lives at `codex/`. Deployed to `~/.codex/`.

- `AGENTS.md` with Claude-parity guardrails and workflow intents
  (context-prime, commit, pr-create, debug, test, dependencies,
  security-audit, feature-spec, pipeline).
- `config.toml` (host) sets `sandbox_mode = "workspace-write"`,
  `approval_policy = "on-request"`.
- `config.container.toml` (container) sets
  `sandbox_mode = "danger-full-access"` (container is the boundary),
  `approval_policy = "on-request"` (independent of sandbox mode).
- `skills/claude-parity/` maps user intent to Claude Code-style workflows.
- `hooks.json` wires Codex PreToolUse hooks through `~/.codex/hooks/`
  wrappers, which exec the shared `~/.agent-hooks/` implementations so
  sensitive-path, commit-message, and no-emoji behavior stays in sync.
- `hooks/notify.sh` sends Pushover notifications when idle.
- Shell aliases: `cx` (codex), `cxe` (codex exec), `cxr`
  (codex review --uncommitted).

## Copilot CLI

Lives at `copilot/`. Deployed to `~/.copilot/`.

Minimal: guardrails, tool preferences, MCP policy, working style. Copilot CLI
has no OS-level sandbox of its own. The container boundary is the only
isolation layer in devcontainers. On hosts, Copilot inherits the user's
process environment with no enforcement beyond the `--deny-tool` CLI flag.

## Per-tier behavior

Same dotfiles, different deployed shape:

| Tier               | Claude settings deployed     | Codex config deployed              | Sandbox state                      |
|--------------------|------------------------------|------------------------------------|------------------------------------|
| Host               | `settings.json`              | `config.toml`                      | `sandbox.enabled=true`             |
| Local devcontainer | `settings.container.json`    | `config.container.toml`            | `sandbox.enabled=false` (container is boundary) |
| Codespaces         | `settings.container.json`    | `config.container.toml`            | `sandbox.enabled=false`            |

Dispatch happens in `bootstrap/symlinks.sh` via `_deploy_variant_file`, gated
on `is_devcontainer()`. `bin/settings-drift.sh` (wired into `make lint`)
verifies that the host and container variants stay in sync on every key
outside the per-tier sandbox block.

In **devcontainers and Codespaces**, an opt-in iptables egress allowlist is
available via `DOTFILES_DEVCONTAINER_EGRESS=1` + `--cap-add=NET_ADMIN` in
`runArgs`. See [sandbox.md](sandbox.md#egress-allowlist-opt-in).

## MCP servers

MCP servers are **not installed** by these dotfiles. Claude Code's built-in
tools (Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch) cover most
workflows without the context overhead of MCP tool descriptions.

If an MCP server is already configured (in `settings.local.json` or
`.mcp.json`), the AI tools will use it. The dotfiles don't install or
configure new MCP servers without explicit user request.

Security notes:

- MCP servers run as child processes with full filesystem and network access.
- They bypass `settings.json` deny rules (credential blocking does not apply
  to MCPs).
- Treat `.mcp.json` files as security-sensitive (they configure arbitrary
  child processes).
- Never store MCP auth tokens in `settings.json` (use `settings.local.json`,
  which is not tracked by dotfiles).
