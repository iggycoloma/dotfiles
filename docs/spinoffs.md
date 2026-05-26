# Spinoffs (future direction)

Parts of this repo that could reasonably live on their own once they earn it.
These are notes, not commitments -- nothing here is being actively split out.

## State persistence as a devcontainer Feature

**What's there today.** Local devcontainers need one volume-mount line in
`devcontainer.json`:

```jsonc
"mounts": [
  "source=${devcontainerId}-state,target=/home/vscode/.dotfiles-state,type=volume"
]
```

Docker named volumes must be declared before the container starts;
`install.sh` runs inside the container and cannot create them. So the mount
line is the smallest amount of per-project boilerplate that's achievable
without a separate distribution artifact.

**The spinoff.** Publish the dotfiles install as a devcontainer Feature on
GHCR. The spec supports `mounts` with `${devcontainerId}` substitution -- the
`docker-in-docker` Feature uses this exact pattern. A Feature could declare
both the mount and the install command, shrinking the project's
`devcontainer.json` to:

```jsonc
"features": {
  "ghcr.io/iggycoloma/dotfiles-agent-tools:1": {}
}
```

**Trade-off.** Publishing pipeline, versioning discipline, OCI artifact
maintenance. Defer until either the one-line coupling becomes annoying or
there's a second consumer.

For implementation rationale and the alternative we evaluated and rejected
(workspace-local state), see [`future-workspace-local-state.md`](future-workspace-local-state.md).

## Unattended coding harness as a standalone package

**What's there today.** The `unattended/` subtree is the "second product"
in this repo:

- `unattended/scripts/ralph.sh` -- autonomous loop runner for Claude Code.
- `unattended/scripts/ralph-parallel.sh` -- N loops across separate worktrees.
- `unattended/bootstrap/unattended-*.sh` -- hardened devcontainer profile
  setup (mitmproxy egress allowlist, vulnerability scanners, entrypoint
  validation).
- `unattended/templates/` -- PRD, prompt, progress templates.
- `unattended/devcontainer-rubric.json` -- consumed by `bin/dc-audit.sh`.

Already opt-in: `./install.sh --with-unattended` or
`DOTFILES_INSTALL_UNATTENDED=1`. Lives at `~/.unattended/` when deployed.
See [`../unattended/README.md`](../unattended/README.md) for the harness's
own docs.

**The spinoff.** Distribute the unattended harness independently of the
dotfiles. A standalone repo or npm/pipx package could let non-dotfiles
users adopt `ralph.sh` + the unattended profile + the linter without
committing to the rest of the developer environment.

**Trade-off.** Today the harness reuses `bootstrap/logging.sh` and
`bootstrap/detect.sh` from the dotfiles. A standalone distribution would
need to vendor or replicate those. Currently, the cost of vendoring is small
but the user base is one -- defer until there's a second adopter.

## Workspace-local state (evaluated, rejected)

We evaluated and implemented a tier that stored Claude Code / Codex / gh
state in `<workspace>/.dotfiles-state/` (gitignored), to avoid the volume
mount requirement for local devcontainers. It worked technically, but was
removed.

**Reason.** Placing auth tokens inside the project tree is a security
footgun. Even protected by both `.gitignore` and `.git/info/exclude`, the
state directory can be exposed by:

- Backup tools that don't respect `.gitignore`.
- Archive uploads (`tar`, `zip` of the project directory).
- Docker `COPY` or `ADD` commands in Dockerfiles.
- CI/CD tools or scanners that read the full workspace.
- Accidental `git add -A` if the gitignore entry is removed.

The blast radius outweighs the convenience of avoiding a one-line volume
mount. See [`future-workspace-local-state.md`](future-workspace-local-state.md)
for the full analysis (problem, three-tier proposal, implementation sketch,
and the decision rationale).

## Shared instruction-file partials

**What's there today.** Six instruction files (project `AGENTS.md` /
`CLAUDE.md`, global `claude-code/CLAUDE.md`, `codex/AGENTS.md`,
`copilot/copilot-instructions.md`, and `.github/copilot-instructions.md`)
have overlapping Guardrails / Preferred CLI Tools / MCP Servers sections.
Today the duplication is acceptable because changes are infrequent and
`tests/test-consistency.sh` enforces parity on the highest-stakes piece
(the credential deny-list).

**The spinoff.** A templating-at-deploy-time pass that holds shared
sections as partials (`shared/guardrails.md`, `shared/cli-tools.md`,
`shared/mcp.md`) and assembles the six target files during install. The
build would run once at `install.sh` time; the deployed files stay plain
markdown for the AI tools to read.

**Trade-off.** Adds a build step to the install. Worth doing once a
maintenance bug actually bites; until then, the consistency tests are the
guardrail. Out of scope for the current PR.

## Shared Claude/Codex workflow sources

**What's there today.** Claude Code has first-class slash commands and
subagents in `claude-code/commands/` and `claude-code/agents/`. Codex has a
lighter `codex/skills/claude-parity/` skill that maps the same user intents to
Codex-native behavior. The overlap is conceptual, not structural: Claude
frontmatter (`allowed-tools`, `argument-hint`, `$ARGUMENTS`, subagent
dispatch) does not map cleanly to Codex skills.

**The spinoff.** Introduce a neutral workflow source tree that generates or
checks both harness-specific outputs:

- Claude slash command markdown and subagent prompts.
- Codex skill reference files and pipeline role docs.

**Trade-off.** This is premature until the workflows have been hardened through
real use. Prompt drift is lower risk than hook or config drift, and a generator
would add maintenance machinery before the right shared abstraction is obvious.
Revisit when workflow drift causes real bugs or the Codex skill format settles
enough for a clean one-to-one mapping.

## Bash-only egress filtering inside containers

**What's there today.** The opt-in iptables egress allowlist
(`bootstrap/devcontainer-egress.sh`) filters at the container's
network namespace level. iptables OUTPUT applies to every process in
the netns, so when enabled it gates WebFetch and WebSearch as a side
effect of gating bash. See [`docs/sandbox.md`'s "Host vs container"
section](sandbox.md#host-vs-container-a-critical-scope-difference) for
the full explanation.

**The spinoff.** A mechanism that filters only bash subprocesses
inside a container, leaving Claude Code's own process (and therefore
WebFetch / WebSearch) free to reach arbitrary research domains. This
would let the "Sensitive code" recommendation in `docs/sandbox.md`
land without trading away research.

**Why it's hard.** Claude Code spawns bash as the same uid as itself,
so `iptables -m owner --uid-owner` doesn't distinguish them.
Architectural options, all with friction:

- **cgroup-based iptables** (`-m cgroup`). Wrap every bash spawn to
  place the subprocess in a dedicated cgroup; filter on that. Requires
  a launcher in Claude Code's bash invocation path.
- **mitmproxy + selective `HTTPS_PROXY`**. The unattended profile is
  close to this -- it sets `HTTPS_PROXY` globally and uses
  `iptables -m owner --uid-owner` to allow the proxy user direct
  egress. Adapting it for the "Claude Code free, bash filtered" case
  needs a launcher that *unsets* `HTTPS_PROXY` for Claude Code itself.
- **`@anthropic-ai/sandbox-runtime`** evaluation. Referenced in
  `docs/sandbox.md`'s Reference section; not yet evaluated for whether
  it cleanly solves the per-process netns split inside a container.
- **bwrap inside the container**. Explicitly the thing the three-tier
  design rejected on hosts; would re-introduce all the friction
  (seccomp, `CAP_SYS_ADMIN`, AF_UNIX filter, ssh-agent breakage).

**Trade-off.** None of the options are clean enough to ship as a
default. Defer until either (a) sandbox-runtime evaluates cleanly,
or (b) a real user need surfaces. The current escape hatches
(`DOTFILES_EGRESS_EXTRA_HOSTS` for research domains, or skip the
egress allowlist entirely for hobbyist use) are good enough for now.
