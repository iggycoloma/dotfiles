Sandbox Posture for Agentic CLIs

This doc describes the OS-level sandbox posture for the three agentic CLIs this
repo deploys (Claude Code, Codex CLI, Copilot CLI) across the three environments
this repo supports (hosts, local devcontainers, GitHub Codespaces).

The architecture is **three tiers, not one**: the right sandbox boundary in each
tier is different. Trying to use the same mechanism everywhere produced one
incompatibility after another. The tiered model is the simpler answer.

Three-tier posture
==================

| Tier                | Filesystem isolation | Network egress                                  | Sandbox config file        |
|---------------------|----------------------|--------------------------------------------------|----------------------------|
| Host (macOS)        | Seatbelt             | `allowedDomains` (Claude Code) + macOS Seatbelt | `claude-code/settings.json` |
| Host (Linux/WSL2)   | bwrap                | `allowedDomains` (kernel-enforced via netns)    | `claude-code/settings.json` |
| Local devcontainer  | container boundary   | iptables (opt-in, `NET_ADMIN` required)         | `claude-code/settings.container.json` |
| Codespaces          | container boundary   | iptables (opt-in, same as devcontainers; binary install required) | `claude-code/settings.container.json` |

`install.sh` chooses which settings file to deploy to `~/.claude/settings.json`
based on `is_devcontainer()`: container variants in devcontainers and Codespaces,
host variants on macOS, Linux, and WSL2 hosts. Same pattern for Codex CLI
(`codex/config.toml` vs `codex/config.container.toml`).

Why three tiers
---------------

The original design tried to run bwrap *inside* devcontainers, then patched
around the friction:

- Claude Code's WSL2 detection (`/proc/sys/kernel/osrelease` contains "microsoft")
  fires inside Linux containers running on WSL2 hosts. bwrap then tries to bind
  Windows host paths (`/mnt/c`, Program Files, managed-settings) that do not
  exist inside the container. Workaround: pre-seed the paths from `install.sh`.
- Docker's default seccomp profile blocks the namespace-creation syscalls bwrap
  needs. Workaround: `--security-opt=seccomp=unconfined` in runArgs.
- The kernel additionally gates `CLONE_NEWNS` on `CAP_SYS_ADMIN`. Workaround:
  `--cap-add=SYS_ADMIN`.
- bwrap on Linux installs a seccomp filter that unconditionally blocks
  `socket(AF_UNIX, ...)`, breaking ssh-agent reachability for signed git commits.
  No setting bypasses this on Linux (issue [#44180](https://github.com/anthropics/claude-code/issues/44180)
  is the open feature request; `excludedCommands "git *"` does *not* work per
  [#10767](https://github.com/anthropics/claude-code/issues/10767),
  [#29274](https://github.com/anthropics/claude-code/issues/29274)).

Each workaround was correct in isolation, but the pattern was that container
config kept encoding *host-OS* knowledge. That dependency direction is wrong:
the container should not need to know what host it is running on.

The pivot: **the container is itself a kernel-enforced isolation primitive,
and bwrap inside a container is defense-in-depth with high maintenance cost.**
Drop bwrap inside containers, keep it on hosts where it has no leaky abstractions.
Use iptables for in-container egress (opt-in), because iptables is host-OS-blind
and operates in the container's own network namespace.

Hosts
=====

Hosts run the full Claude Code Bash sandbox: `sandbox.enabled: true` in
`claude-code/settings.json`. Filesystem isolation is enforced by Seatbelt on
macOS and bubblewrap on Linux/WSL2; both are installed by `bootstrap/packages.sh`
on Linux (`bubblewrap` + `socat` packages) and built-in on macOS.

Network egress is enforced by `sandbox.network.allowedDomains` via a host-side
HTTP proxy. On Linux, bwrap unshares the network namespace and bridges via socat
into the proxy, so the policy is kernel-enforced for every bash subprocess. On
macOS, Seatbelt enforces a similar boundary.

SSH agent and signed commits
----------------------------

bwrap's default Linux profile installs a seccomp filter that blocks
`socket(AF_UNIX, ...)`. This breaks ssh-agent reachability from any sandboxed
bash command -- including `git commit` when commits are SSH-signed via the agent.

Status by host platform:

- **macOS**: `sandbox.network.allowUnixSockets` accepts a path glob. The dotfiles
  config narrowly allows the launchd-bridged ssh-agent path
  (`/private/tmp/com.apple.launchd.*/Listeners`). Signed commits in-session work.
- **Linux + WSL2**: no equivalent setting exists. Issue
  [#44180](https://github.com/anthropics/claude-code/issues/44180) tracks the
  upstream fix. The two SSH-signing variants behave differently inside the
  sandbox:
  - **File-based** (`user.signingkey` = path to `~/.ssh/id_ed25519.pub`):
    works. `ssh-keygen` derives the private key path by stripping `.pub`
    and reads the file directly -- no AF_UNIX socket, so the bwrap seccomp
    filter is irrelevant. `install.sh` falls back to this when no agent
    is reachable at install time.
  - **Agent-based** (`user.signingkey` = `"key::<literal-pubkey>"`):
    broken. ssh-keygen must contact `SSH_AUTH_SOCK`, which requires
    `socket(AF_UNIX, ...)`. `install.sh` prefers this when an agent is
    loaded at install time, so signing breaks for those users in-sandbox.
    Workaround: re-run `git config --global user.signingkey
    ~/.ssh/id_ed25519.pub` to switch to file-based, or run `git commit`
    in a separate terminal until upstream lands a Linux equivalent of
    `allowUnixSockets`.

Settings precedence (managed > CLI > local > project > user) means an
organization can enforce sandboxing for every developer via managed settings;
this repo only ships user-level config.

Local devcontainers
===================

Container = sandbox. `claude-code/settings.container.json` sets
`sandbox.enabled: false`, and Codex's `codex/config.container.toml` sets
`sandbox_mode = "danger-full-access"`. No bwrap inside, no host-OS workarounds
in devcontainer.json.

What that means in practice:

- `~/.ssh`, `~/.aws`, etc. on the host are unreachable from inside the
  container (Docker's filesystem boundary). The deny-glob entries in
  `permissions.deny[]` still gate Claude Code's own file tools against in-project
  secret patterns (`**/*.pem`, `**/credentials*`, `.env*`).
- ssh-agent is reachable normally (no seccomp filter installed), so signed
  commits work in-session.
- Network egress is unrestricted by default. The container itself has the
  Docker bridge's view of the network. To restrict, opt into the iptables
  egress allowlist (below).

Egress allowlist (opt-in)
-------------------------

`bootstrap/devcontainer-egress.sh` installs iptables OUTPUT rules that allow
only a small set of agentic-tool + code-management endpoints (Anthropic API,
GitHub, npm/pypi/crates registries) plus loopback + DNS + established
connections. Default policy after the rules: DROP. Project-specific extras via
`DOTFILES_EGRESS_EXTRA_HOSTS`.

Gating (all required):

1. `DOTFILES_DEVCONTAINER_EGRESS=1` in the environment.
2. `--cap-add=NET_ADMIN` in devcontainer.json runArgs.
3. Running inside a devcontainer.
4. `DOTFILES_NO_AI_TOOLS != 1`.

The script is invoked at the end of `install.sh`. When the gates fail, it logs
the reason and exits 0 -- safe to leave wired in the installer regardless of
whether a particular container has the cap.

This is *opt-in* by default because most users don't want a network policy
imposed unconditionally, and because NET_ADMIN is a privileged capability that
not all hosts allow. The `.devcontainer/example/devcontainer.json` template
includes a comment explaining the opt-in pattern.

Persistence model
=================

Single shared Docker volume + symlinks. A project devcontainer.json declares
one mount line:

```jsonc
"mounts": [
  "source=${devcontainerId}-state,target=/home/vscode/.dotfiles-state,type=volume"
]
```

`install.sh` creates `~/.dotfiles-state/` and symlinks `~/.claude`, `~/.codex`,
`~/.copilot` into subdirectories of it. Symlinks everywhere -- on hosts and in
containers -- because the bwrap-mount-over-symlink-into-volume-submount conflict
that previously forced "copy in containers" no longer exists (no bwrap inside).

Membership rule: dotfiles persists state for what dotfiles installs. Currently
that's Claude Code, Codex CLI, and Copilot CLI. Other tools (gh, kubectl, docker)
are out of scope -- projects own their own persistence.

Codespaces relies on platform-level `/home/vscode` persistence across stop/start
(rebuilds re-auth, accepted). The dotfiles symlink layout still works; just no
explicit volume mount.

Ownership normalization
-----------------------

Docker creates a fresh named volume root-owned. The mount happens during
container start, *before* `postCreateCommand` runs `install.sh`. `install.sh`
detects a root-owned `~/.dotfiles-state` and `sudo chown` recursively before the
symlinks are created. Idempotent: once user-owned, the volume stays that way
across rebuilds.

Option H: devcontainer Feature (future)
----------------------------------------

The single mount line in each project devcontainer.json is the minimum coupling
mathematically achievable without a separate distribution artifact. To eliminate
even that, publish the dotfiles install as a devcontainer Feature on GHCR. The
spec supports `mounts` with `${devcontainerId}` substitution (the
docker-in-docker feature uses this exact pattern), so a Feature could declare
both the mount and the install command. Project devcontainer.json shrinks to:

```jsonc
"features": {
  "ghcr.io/iggycoloma/dotfiles-agent-tools:1": {}
}
```

Trade-off: publishing pipeline, versioning discipline, OCI artifact maintenance.
Defer until the one-line coupling becomes annoying or there's a second consumer.

Devcontainer.json linter
========================

`bootstrap/lint-devcontainer.sh` is a security-focused linter that scans
devcontainer.json files for patterns that would punch holes in the container
boundary. It's wired into `make lint` via the `lint-devcontainer-security`
target. Checks:

- **Risky mounts**: `docker.sock`, ssh-agent forwarding, `~/.ssh`, `~/.aws`,
  `~/.gnupg`, `~/.azure`, `~/.config/gh`, `~/.config/gcloud`, `~/.kube`,
  `~/.docker`. Source-side substring match against `source=...` entries.
- **Credential env pass-through**: `AWS_*`, `GCP_*`/`GOOGLE_APPLICATION_*`,
  `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GH_TOKEN`, `GITHUB_TOKEN`, `NPM_TOKEN`
  in containerEnv or remoteEnv.
- **Public port forwards**: forwardPorts entries that explicitly bind 0.0.0.0.
- **Drift check**: `claude-code/settings.json` and `settings.container.json`
  must match on every key outside `.sandbox` (so permission rules, hooks,
  status line, etc. stay in sync between host and container variants).

Advisory by default. Pass `--strict` to exit 1 on any warning (suitable for CI).
The repo's `unattended` profile intentionally passes `GH_TOKEN` for the agentic
ralph harness; that warning is expected.

Tool-specific notes
===================

Claude Code
-----------

Host vs container variant lives at `claude-code/settings.json` and
`claude-code/settings.container.json`. Both files mirror each other on
`permissions`, `hooks`, `statusLine`, `env`, etc. Only the `sandbox` block
differs:

- Host: `sandbox.enabled: true`, full filesystem/network config.
- Container: `sandbox.enabled: false`, nothing else under sandbox.

The `permissions.deny[Read|Write|Edit]` glob list applies in both variants --
that gates Claude Code's own file tools, independent of the OS sandbox. The
in-project secret-pattern globs (`**/*.pem`, `**/credentials*`, `.env*`) still
catch interpreter bypasses there.

Codex CLI
---------

Same pattern: `codex/config.toml` (host) and `codex/config.container.toml`
(container). The host variant uses `sandbox_mode = "workspace-write"`; the
container variant uses `sandbox_mode = "danger-full-access"` because the
container is the boundary. Approval policy stays `on-request` in both -- the
human-in-the-loop gate is independent of sandbox mode.

Copilot CLI
-----------

Copilot CLI has no OS-level sandbox of its own. The container boundary is the
only isolation layer in devcontainers. On hosts, Copilot inherits the user's
process environment with no enforcement beyond the `--deny-tool` CLI flag
(which has no persistent equivalent). The dotfiles ship `copilot-instructions.md`
but do not pretend to enforce a sandbox.

Codespaces graceful degradation
================================

Codespaces' Azure-hosted kernel disallows the unprivileged user namespaces bwrap
needs, so bwrap cannot start there. `failIfUnavailable: false` in the host
settings lets Claude Code fall back to unsandboxed mode rather than failing
startup -- but in Codespaces we use the *container* variant settings anyway
(`is_devcontainer()` returns true for Codespaces), so the fallback path is not
the primary concern. The container's process and filesystem isolation remain.

Iptables in Codespaces is **supported**, verified empirically. NET_ADMIN is
in the container's bounding set (`/proc/self/status` `CapBnd` includes
`cap_net_admin`), `sudo` elevates to root, and both `iptables` and
`ip6tables` rules can be added and removed against the OUTPUT chain.

One caveat: the Codespaces base image
(`mcr.microsoft.com/devcontainers/base:ubuntu`) does not ship the `iptables`
userspace binary by default. `bootstrap/devcontainer-egress.sh` detects this
and prints an install hint; users opting into egress restriction in
Codespaces add `iptables` to their devcontainer's `apt-get install` step or
let install.sh install it (gated on `DOTFILES_DEVCONTAINER_EGRESS=1`).

For projects that want egress restriction by default in Codespaces, store
`DOTFILES_DEVCONTAINER_EGRESS=1` as a [Codespaces secret](https://docs.github.com/en/codespaces/managing-your-codespaces/managing-your-account-specific-secrets-for-github-codespaces);
Codespaces makes secrets available as environment variables inside the
container automatically.

Inside a devcontainer
======================

`install.sh` detects the container via `is_devcontainer()`, which checks the
`REMOTE_CONTAINERS` and `CODESPACES` env vars first and falls back to the
`/.dockerenv` sentinel that Docker creates at container start (so plain
`docker run` shells and devcontainers built without the VS Code remote helper
exporting the env var still resolve correctly). Then:

1. Deploys `claude-code/settings.container.json` over `~/.claude/settings.json`.
   On hosts this would be a symlink to the source file; in containers it is a
   copy (avoiding a symlink dependency that could break if the source repo is
   not present in the container).
2. Deploys `codex/config.container.toml` over `~/.codex/config.toml`. Same
   copy-not-symlink pattern.
3. Wires `~/.claude`, `~/.codex`, `~/.copilot` as symlinks under
   `~/.dotfiles-state/` (when the volume mount is present), or as plain real
   directories (when it is not).
4. Normalizes ownership of `~/.dotfiles-state/` if root-owned (first-mount fix).
5. Optionally installs the iptables egress allowlist (gated on env var +
   NET_ADMIN cap).

The container does not install `bubblewrap` or `socat` -- those are skipped in
`bootstrap/packages.sh` when `is_devcontainer()` is true.

Limitations and known gaps
==========================

- **Linux ssh-agent-based signed commits**: blocked by the unconditional
  AF_UNIX seccomp filter. Tracked at issue
  [#44180](https://github.com/anthropics/claude-code/issues/44180).
  File-based SSH signing works in-sandbox (see "SSH agent and signed
  commits" above for how to switch); agent-based signing needs a separate
  terminal until upstream lands a Linux `allowUnixSockets` equivalent.
- **Codespaces iptables base image**: the Microsoft Ubuntu base image does
  not ship the `iptables` binary. Egress restriction in Codespaces requires
  `apt-get install -y iptables` first; `bootstrap/devcontainer-egress.sh`
  prints an install hint if the binary is missing.
- **Host network proxy and TLS**: the built-in proxy enforces by hostname
  without TLS termination. Broad allowedDomains entries (e.g. `github.com`)
  can be domain-fronted by attacker code running inside the sandbox. Threat
  models requiring TLS-aware filtering need a custom proxy.
- **Iptables and DNS-based exfil**: even with egress restricted to an
  allowlist, attacker code can dial allowed destinations (e.g. push to a
  controlled github.com repo). Iptables narrows the channel; it does not
  close it entirely.
- **Settings file drift**: `claude-code/settings.json` and
  `claude-code/settings.container.json` are two physical files maintained in
  parallel. The linter's drift check enforces sync on non-sandbox keys.
  Adding a key to one without the other is a `make lint` warning.

CVEs and updates
================

Keep Claude Code auto-updated. Sandbox-relevant CVEs (e.g. CVE-2026-25725,
settings.json injection sandbox-escape) have shipped fixes; auto-update is
the path to consume them.

Reference
=========

- [Configure the sandboxed Bash tool (Claude Code docs)](https://code.claude.com/docs/en/sandboxing)
- [Dev Container Features reference](https://containers.dev/implementors/features/)
- [docker-in-docker feature (example of ${devcontainerId} in feature mounts)](https://github.com/devcontainers/features/blob/main/src/docker-in-docker/devcontainer-feature.json)
- [@anthropic-ai/sandbox-runtime (npm package, optional)](https://www.npmjs.com/package/@anthropic-ai/sandbox-runtime)
