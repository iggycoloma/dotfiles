# Research: Claude Code Configuration

## Q1: Why two-layer security (deny globs + pre-security.sh hook)?

**Decision**: Maintain both layers. Settings.json deny rules are the
primary boundary for file-content risk; `pre-security.sh` is the
secondary layer for Bash command-string scanning.

**Options considered**:

1. **Deny globs only**. Simple, all in JSON. But globs only match the
   `file_path` argument; they cannot inspect `Bash(command: "cat
   ~/.aws/credentials")`. The `Bash(<prefix>:*)` rule can only prefix-
   match, missing pipes, subshells, and indirection (`xargs cat
   ~/.aws/credentials`).
2. **Hook only**. One mechanism, less drift. But the hook is bypassable
   by hook process failure (exit 1 with no JSON output) -- the framework
   defaults to `allow`. A failed hook should not silently widen
   permissions.
3. **Both layers (chosen)**. Settings rules cover the deterministic file-
   path case; hook covers the indirected Bash case. Each layer is
   sufficient for what it covers; together they leave less surface for
   miss-or-bypass.

**Rationale**: The constitution's Article II ("Defense-in-Depth
Security") explicitly forbids relying on a single layer. The cost is
some duplication: both layers list `~/.ssh`, `~/.aws`, etc. We accept
this in exchange for not relying on either one to be flawless.

**Trade-off**: Drift risk between the two lists. Mitigated by
`tests/test-consistency.sh` which validates list parity across
settings.json, CLAUDE.md, codex/AGENTS.md, and copilot/copilot-
instructions.md.

## Q2: Why deploy AI tool config via stomp-copy in devcontainers, not symlinks?

**Decision**: Devcontainers force-copy on every boot; hosts symlink.

**Options considered**:

1. **Symlink everywhere**. Simple, single mode. But devcontainers are
   ephemeral -- the dotfiles repo lives in `/workspaces/.dotfiles` and a
   symlink from `~/.claude/settings.json -> /workspaces/.dotfiles/...`
   would survive across rebuilds. **Problem**: when the user updates
   the dotfiles via `git pull`, settings.json updates immediately
   without a re-install; subtle drift between expected and actual hook
   wiring. Worse, atomic file writes (`mv tmp ~/.claude/settings.json`
   from any tool) replace the symlink with a regular file, silently
   breaking the dotfiles link.
2. **Stomp-copy everywhere**. Containers always reflect current
   dotfiles. But on hosts, this means `git pull` requires a re-install
   to take effect -- friction during dotfiles development.
3. **Branch on environment (chosen)**. Hosts get symlinks (live edits
   propagate); devcontainers get force-copies (per-boot freshness, no
   broken symlinks from atomic writes).

**Rationale**: The two environments have opposite needs. Hosts are
long-lived and edits to dotfiles are common; devcontainers are
ephemeral and the user expects a fresh state on rebuild. The branch
adds complexity but eliminates the "dotfiles changed but containers
still see old config" footgun.

**Trade-off**: `_deploy_configs` is bimodal. Tests verify both modes;
the function is small enough that the branch is readable.

## Q3: Why an explicit allow-list of ~70 Bash commands?

**Decision**: Pre-allow common safe Bash commands so users aren't
prompted on every `git status` or `ls`.

**Options considered**:

1. **No allow-list**. Every Bash call requires user confirmation.
   Realistic in security-critical sessions; impossibly noisy for
   day-to-day use.
2. **Tool-level Bash permission**. Allow all Bash unconditionally.
   Removes the prompts but eliminates the deny-list defense entirely
   (deny rules only apply when allow rules don't match first).
3. **Command-prefix allow-list (chosen)**. Allow specific safe
   commands; deny destructive ones; everything else prompts.

**Rationale**: The allow-list is a conscious productivity / safety
trade-off. Reading file lists, git status, gh PR queries, package-
manager listings -- none of these mutate state or read credentials, so
prompting on them adds noise without value. Anything that could
mutate or read credentials either falls through to the deny rules or
prompts.

**Trade-off**: The allow-list grows over time; periodic audit needed
to ensure no entry has become risky.

## Q4: Why MCP servers explicitly NOT installed by default?

**Decision**: No MCP servers ship with the dotfiles. Users must opt in
per-machine via `~/.claude/.mcp.json`.

**Options considered**:

1. **Pre-install useful MCPs (filesystem, github)**. Good UX, instant
   capability. But MCP servers run as child processes with full
   filesystem and network access -- they bypass the deny rules in
   settings.json. A pre-installed filesystem MCP could read .env files
   even though `Read(.env)` is denied at the tool level.
2. **Allow-list specific MCPs**. Same problem -- once running, the
   child process bypasses Claude's permission framework entirely.
3. **No MCPs by default; user opt-in (chosen)**. Removes the
   "credential blocking I trust does not actually block" surprise.
   Documented in CLAUDE.md so users know to audit any MCP they add.

**Rationale**: The constitution's Article II requires defense-in-depth.
MCP servers, by design, sit outside the depth -- they are a separate
trust boundary. Pre-installing them would hide that fact from users.

**Trade-off**: New users miss out on MCP capabilities until they read
the documentation. Mitigated by SessionStart banner pointing to MCP
posture in CLAUDE.md.
