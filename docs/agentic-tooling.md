# Agentic tooling

How Claude Code, Codex CLI, and Copilot CLI are integrated. For the sandbox
posture (host vs container, egress, signing), see [`sandbox.md`](sandbox.md).
For the autonomous-loop harness (`ralph.sh`, unattended profile), see
[`../unattended/README.md`](../unattended/README.md).

## Installation

Claude Code and Codex CLI are installed automatically as **native binaries** on
every environment -- hosts, devcontainers, and Codespaces alike. No devcontainer
features, no Node.js required. macOS goes through the same path as Linux: Codex
publishes `codex-ARCH-apple-darwin.tar.gz` and the OS detection maps `Darwin` to
`apple-darwin`, so there is no brew special-case.

These are developer tools rather than project-dependent ones, so they sit in the
tier this repo installs (alongside ripgrep and starship), not the config-only
tier shared with `gh` and `kubectl`. Hosts were devcontainer-only until
[#71](https://github.com/iggycoloma/dotfiles/pull/71); that was a scope artifact
of the original devcontainer-features migration rather than a decision, and it
left Linux hosts installing `bubblewrap` and `socat` -- which exist solely to
back Claude Code's sandbox -- without installing Claude Code.

Both installers are **install-if-missing, not upgrade**. An existing `claude` or
`codex` already on `PATH` is left alone, so re-running `install.sh` will not pull
a newer version; both tools self-update in place. To force a reinstall, remove
the binary first.

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
| Hooks           | 3     | Security blocking, no-emoji, idle notification                          |
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

| Hook                      | Trigger (Claude Code) | Action                                                         |
|---------------------------|------------------|---------------------------------------------------------------------|
| `pre-security.sh`         | Read/Write/Edit/Bash | Blocks ~50 sensitive file patterns and credential directories   |
| `pre-code-no-emoji.sh`    | Write/Edit       | Blocks decorative emoji in code files                               |
| `notify.sh`               | Notification     | Pushover notification when Claude is idle and waiting for input     |

Exit codes: `0` = continue, `2` = block (stderr shown as denial reason).
Other non-zero codes are logged but don't block.
The shared hooks take the exit-0 route: they always exit 0 and return the
decision as `hookSpecificOutput.permissionDecision` JSON on stdout, which both
Claude Code and Codex parse.

#### Coverage is not symmetric across tools

The Trigger column above is Claude Code only.
Codex exposes a different tool surface, so the same shared implementation
guards less there:

| Guard                | Claude Code                       | Codex                              |
|----------------------|-----------------------------------|------------------------------------|
| Bash command scan    | Yes (`Bash`)                      | Yes (`Bash`)                       |
| File-write path scan | Yes (`Write`/`Edit`/`MultiEdit`)  | Yes (`apply_patch`), Codex >= 0.123.0 |
| File-read blocking   | Yes (`Read`)                      | No -- no read tool fires PreToolUse |
| No-emoji guard       | Yes (`Write`/`Edit`)              | Yes (`apply_patch`), Codex >= 0.123.0 |

Three things drive the difference.

Codex has no `Read`, `Write`, or `Edit` tool -- file edits arrive as
`apply_patch` -- so matchers must name `apply_patch`.
A matcher using Claude's tool names is dead wiring, which is what
`tests/test-hook-matchers.sh` exists to catch.

`apply_patch` did not emit hook events at all until Codex 0.123.0
([#16732](https://github.com/openai/codex/issues/16732),
[#17794](https://github.com/openai/codex/issues/17794)).
On anything older, only the Bash scan is live; check with `codex --version`.

Credential-read blocking is not achievable on Codex at any version.
Its `read_file` and `grep` handlers implement no `pre_tool_use_payload`, so no
hook fires ([#20204](https://github.com/openai/codex/issues/20204),
[#18491](https://github.com/openai/codex/issues/18491)).
The Bash scan catches shell-based reads such as `cat ~/.ssh/id_rsa`, which is
the partial mitigation.

Note that `unified_exec` -- Codex's streaming shell path -- is covered.
It fires `PreToolUse` reporting `tool_name` as `Bash` with a string
`tool_input.command`, so the existing Bash matcher and the `TOOL_NAME == "Bash"`
branch in `pre-security.sh` handle it with no extra wiring.

`tests/test-hook-matchers.sh` locks this down: it checks that every matcher in
`claude-code/settings.json` and `codex/hooks.json` names a tool its platform
actually emits, and that the wired hook dispatches on it.
The `test-security-hook.sh` and `test-emoji-hook.sh` suites feed payloads
straight into `agent-hooks/`, bypassing the matcher layer, so they cannot catch
a dead matcher on their own.

Commit message validation lives in `git/hooks/commit-msg` (installed via
`core.hooksPath`). There is intentionally no PreToolUse equivalent: a
hook that only sees the raw `Bash` command string cannot reliably parse
every shape git accepts (`-m`, `-F`, `--file=`, `-t`, heredocs, editor),
so an apparent gate would silently allow whichever shapes it failed to
parse. `commit-msg` runs against the resolved message file after git
has handled every input form, so coverage is uniform across input
shapes. Behavioral tests live in `tests/test-commit-msg-hook.sh`.

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
  wrappers, which exec the shared `~/.agent-hooks/` implementations. Matchers
  name Codex's own tools (`Bash`, `apply_patch`) -- not Claude's
  `Read`/`Write`/`Edit`, which Codex never emits. Behavior is shared, but
  coverage is narrower than Claude Code's; see
  [Coverage is not symmetric across tools](#coverage-is-not-symmetric-across-tools).
  Commit messages are validated by git's `commit-msg` hook, not by an agent hook.
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
on `is_devcontainer()`. The Claude container variant is generated from the host
one by `bin/sync-settings.sh` (`make sync-settings`), so edit `settings.json`
only. `bin/settings-drift.sh` (wired into `make lint`) verifies the generated
copy is current and that the hand-maintained Codex pair stays in sync on every
key outside the per-tier sandbox block.

In **devcontainers and Codespaces**, egress is unrestricted by default;
the container boundary plus a `bin/dc-audit.sh`-linted spec is the
security model. For unattended runs that need a hostname allowlist
enforced inside the container, start from
[`.devcontainer/unattended/`](../.devcontainer/unattended/devcontainer.json)
(mitmproxy + `unattended/egress-allowlist.txt`). See
[sandbox.md](sandbox.md#host-vs-container-scope-difference).

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
