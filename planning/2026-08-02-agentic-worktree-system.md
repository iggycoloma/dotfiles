# Plan: Codifying the Agentic Worktree Dev Environment

Status: proposed, not started. Revision 3 (2026-08-02).
Source design: [`docs/agentic-worktree-dev-environment.md`](../docs/agentic-worktree-dev-environment.md) (untracked in the main checkout -- see Phase 0).

Revision history:
- r1 recommended `.claude/worktrees/` as canonical. Wrong: conflated placement with naming, and failed the harness-agnostic requirement.
- r2 corrected to nested + vendor-neutral, redirecting Claude Code via `WorktreeCreate`.
- r3 adds the **host/container execution model** (section 3), which voids one of r2's arguments for nesting (3.3) and makes the devcontainer CLI a first-class dependency.
- r4-r5: state-volume tier split, `./dev verify` / lifecycle / credential-delivery decisions, `worktree.useRelativePaths` and mount-topology spikes executed and passed, installer verification finding.
- r6: maintainer constraints recorded (section 1.1) -- **Codespaces in-container flows are a hard compatibility requirement**; ralph stack exempt from compatibility. Session evidence log added (section 10).

## 1. Goal

One worktree system serving Claude Code, Codex CLI, Copilot CLI, and a human at a shell, with three governing constraints:

1. **Harness-agnostic.** No harness gets a privileged path; no harness's absence breaks the others.
2. **Host stays clean.** The host carries Docker, VS Code, and the agent CLIs -- no project toolchains. The devcontainer spec is the single definition of the build/test environment.
3. **Both execution models stay supported.** Host-primary (section 3) is the new default, but the existing in-container model -- agent running inside the devcontainer, as in GitHub Codespaces -- must keep working unchanged. The host-primary model is additive, never a replacement.

### 1.1 Maintainer constraints (recorded 2026-08-02)

Decisions from the maintainer that bound this plan; do not relitigate without new input.

- **Codespaces compatibility is a hard requirement.** In Codespaces the agent necessarily runs in-container; there is no host tier. Everything in this plan must degrade cleanly to that topology. Concretely:
  - Nested worktrees inside the workspace mount work in-container with zero configuration -- **this planning session itself ran in a devcontainer inside a nested worktree** and is the standing proof.
  - `wt` core commands (`add`, `sync`, `doctor`, `remove`, ...) must work in-container. `wt container-up`/`wt exec` are host-only; `wt doctor` must detect the in-container case and report those as intentionally unavailable rather than broken.
  - The devcontainer CLI install is gated on `is_devcontainer()` being false; containers never launch containers.
  - Container-tier settings (`settings.container.json`, `sandbox.enabled: false`) stay as they are.
  - The state-volume tier split (3.5) must respect the Codespaces persistence matrix in `docs/future-workspace-local-state.md` (volumes wiped on full rebuild; `/workspaces` survives). Revisit of `local/`/`state/` location is welcome, but not at Codespaces' expense.
- **The ralph/unattended stack is exempt from compatibility.** Deprecation is planned as a separate, later step. This plan must not break the *rest* of the system to preserve ralph, and owes ralph nothing; Phase 6's job is only to mark the superseded planning doc, not to migrate the stack.
- **In-container agent profile is in scope** (3.4, 3.8): opt-in credential mounting for interactive VS Code work and Codespaces.
- **`./dev verify` is in-container by definition**; `wt remove` tears down the worktree's containers; volumes retained unless `--volumes` (3.8).

## 2. Harness landscape

| Harness | Native worktree support | Implication |
|---|---|---|
| Claude Code | Yes: `--worktree`/`-w`, `EnterWorktree`, subagent `isolation: worktree`, default `.claude/worktrees/<name>/` | Has an opinion; redirect it, don't fight it |
| Codex CLI | **None.** Open request [openai/codex#12862](https://github.com/openai/codex/issues/12862). The Codex *desktop app* has worktrees; the CLI does not | `wt` is the only convention |
| Copilot CLI | None | `wt` is the only convention |
| Human / plain git | n/a | `wt` is the convention |

Three of four consumers have no opinion. The only question is stopping the fourth from diverging.

### 2.1 Claude Code is redirectable programmatically

`WorktreeCreate`/`WorktreeRemove` hooks replace Claude Code's default git worktree logic entirely, **including placing worktrees somewhere other than `.claude/worktrees/`**.

`WorktreeCreate` fires on `--worktree`, subagent `isolation: worktree`, background sessions, and desktop parallel sessions. It receives `worktree_base_path` and `worktree_suffix` on stdin, may ignore both, and prints the created path on stdout. **Non-zero exit aborts creation.**
`WorktreeRemove` receives `worktree_path`, is side-effect-only, and cannot block cleanup.

These live in `settings.json`, which this repo already deploys, syncs to the container variant, and drift-lints. The redirection is fully codifiable -- no GUI step.

Consequences: worktree location becomes our decision, and `.worktreeinclude` is **not** processed when the hook is in play, so we own credential provisioning outright.

### 2.2 Settled for free by the Claude Code docs

- **Sandbox**: "git commands in a worktree write to the main repository's shared `.git` directory, and sandboxing allows those writes" -- removes the largest r1 unknown.
- **`.worktreeinclude` is now first-class in Claude Code**, copying files that match *and* are gitignored. Confined to one harness, sourced from the main checkout, no profiles or refresh. Not a substitute, but the design doc's dismissal of it as purely third-party is outdated.
- **Symlink refusal**: Claude Code refuses to create a worktree when `.claude`, `.claude/worktrees`, or the worktree dir is a symlink. No redirect-by-symlink.
- Project-scope plugins and permission approvals are shared from the main checkout across worktrees.

## 3. Execution model: agent on host, container as executor

This is the organizing principle, and it changes several earlier conclusions.

```
host:       agent CLI  +  wt  +  devcontainer CLI  +  docker  +  VS Code
              |  edits files directly in the worktree (host filesystem)
              |  executes nothing that needs a toolchain
              v
container:  devcontainer up --workspace-folder <worktree>
            devcontainer exec --workspace-folder <worktree> -- ./dev verify
```

The agent reads and writes source on the host, and runs every command that needs a toolchain through `devcontainer exec`.
VS Code opens the same worktree and reopens it in the same spec for interactive debugging.
One spec, two consumers, no divergence.

### 3.1 "Host has only Docker and VS Code" is achievable

The devcontainer CLI's install script **bundles its own Node.js runtime**, installs to `~/.devcontainers` (overridable via `--prefix` / `DEVCONTAINERS_INSTALL_DIR`), and supports Linux and macOS on x64 and arm64; Windows is directed to WSL.
So the host gains exactly one self-contained tool tree and no project toolchains.

This fits the repo's stated boundary: the devcontainer CLI is a developer-level tool like Claude Code and Codex CLI, not a project-dependent one like `kubectl`.
It belongs in `bootstrap/packages.sh`.

Resolved (2026-08-02): the GitHub-release path **does not exist** -- devcontainers/cli publishes no GitHub releases at all. The install script downloads Node.js from `nodejs.org/dist` and the CLI from `registry.npmjs.org/@devcontainers/cli/-/cli-${CLI_VERSION}.tgz`, and **performs no checksum or signature verification on either**.

So the Debian/Ubuntu choices were: (a) vendor a pinned-version install into `bootstrap/packages.sh` that fetches the npm tgz directly and verifies it against the registry packument's published `dist.integrity`/`dist.shasum`; or (b) run the upstream script and accept unverified downloads for this one tool.

**Implemented (Phase 2, 2026-08-02): (b), deliberately.** `install_claude_code` set the precedent -- AI developer tools already install via unverified vendor scripts (`claude.ai/install.sh` piped to bash), so (a) would have held the devcontainer CLI to a stricter standard than the tool launching it. macOS uses the Homebrew formula. The vendored npm-integrity install remains a worthwhile hardening enhancement, filed for both installers together.

### 3.2 The sandbox posture flips from container tier to host tier

Today the agent runs *inside* the devcontainer, where `sandbox.enabled: false` and the container is the boundary.
Under this model the agent runs on the **host**, where `sandbox.enabled: true` with bwrap (Linux/WSL2) or Seatbelt (macOS) and an `allowedDomains` allowlist.

Concrete consequences:

- `excludedCommands` currently exempts `gh *`, `glab *`, `docker *`. **`devcontainer *` must be added** -- it talks to the Docker socket, and bwrap's network namespace would otherwise break it.
- The host agent's write scope is its workspace. Nested worktrees are inside it; sibling worktrees are not (see 3.3).
- `local/` and `state/` sit outside the workspace under any layout, so they remain the genuine sandbox question for Phase 1.

### 3.3 Retraction: per-worktree containers void the "nested needs no devcontainer config" argument

r1 and r2 leaned on a verified result: git works in a worktree inside a devcontainer with zero configuration.
That result is real but **topology-specific**. It holds because this session mounts the *repository root* and the worktree is nested inside that mount.

Under per-worktree containers the topology is different. `devcontainer up --workspace-folder <worktree>` mounts only the worktree, so its `.git` file points at `<repo>/.git/worktrees/<slug>` -- outside the mount -- and in-container git fails.
**This is true whether the worktree is nested or a sibling.** The nesting advantage evaporates.

Therefore `--mount-git-worktree-common-dir` (CLI 0.81.0+) becomes **required infrastructure**, not an optional flag.

#### Verified: the flag works, and nesting is what makes it clean

Tested on the host, 2026-08-02, devcontainer CLI 0.88.0 on WSL2, against a nested relative-path worktree with no custom `workspaceMount`.

**Control, without the flag** -- one bind mount, worktree only:

```
--mount type=bind,source=.../repo/.worktrees/feat,target=/workspaces/feat
$ git status --short
fatal: not a git repository: (null)
```

Confirms the failure mode exactly as predicted.

**With the flag** -- two bind mounts, and note the target paths:

```
--mount type=bind,source=.../repo/.worktrees/feat,target=/workspaces/.worktrees/feat
--mount type=bind,source=.../repo/.git,          target=/workspaces/.git
```

```
toplevel:   /workspaces/.worktrees/feat
common-dir: /workspaces/.git
$ git worktree list
/workspaces                  164712a [main]
/workspaces/.worktrees/feat  164712a [feat]
```

**The CLI preserves the relative structure.** It mounts the worktree at `/workspaces/.worktrees/feat` rather than the usual `/workspaces/feat`, and the common dir at `/workspaces/.git`, so the worktree's relative pointer `../../.git/worktrees/feat` resolves correctly inside the container. This resolves the open question in the appendix: it reconstructs the relationship rather than flattening it.

This is a direct argument for the nested layout that survives everything in 3.3. The relative pointer and the mount reconstruction are the same shape only because the worktree lives inside the repo. A sibling layout would require the CLI to invent a mount topology for an arbitrary relative path.

Two caveats the test surfaced:

- **`/workspaces` is reported as the main worktree, but its files are not mounted.** Only `.git` is. Git infers the main worktree path from the common dir's parent, so `git -C /workspaces status` inside the container would report every tracked file as deleted. Agents must operate on their own worktree and never on the inferred main checkout.
- **`.worktrees/` must be gitignored.** Otherwise the main checkout reports every worktree as untracked.

#### Git writes need an identity the CLI does not supply

The write test was **inconclusive, not failed**:

```
$ git commit --allow-empty -m write-test
Author identity unknown
*** Please tell me who you are.
fatal: unable to auto-detect email address (got 'vscode@2b8a59b12ef4.(none)')
```

That is not a mount or permission failure -- git aborted before touching the object store. But it exposes a real gap: **the devcontainer CLI does not copy the host `.gitconfig` the way the VS Code extension does.** Reads work; writes need identity supplied explicitly.

Under section 3 this is mostly avoidable, because the host agent can commit on the host where identity already exists. It matters for the in-container agent profile (3.4) and for VS Code interactive work. `wt exec` should pass identity via `--remote-env GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` / `GIT_COMMITTER_NAME` / `GIT_COMMITTER_EMAIL` sourced from the host, rather than mounting `.gitconfig`.

Incidental finding: the CLI built an `updateUID.Dockerfile` image variant automatically, aligning the container user's UID with the host user's. That is the mechanism which addresses the bind-mount ownership question in 3.9, though it still needs confirming on macOS.

#### The flag has a hard prerequisite: relative-path worktrees

The CLI's own option description states it plainly:

> `mount-git-worktree-common-dir` -- "Mount the Git worktree common dir for Git operations to work in the container. **This requires the worktree to be created with relative paths (`git worktree add --relative-paths`).**"

This is load-bearing and easy to miss.

- **Today's worktrees do not satisfy it.** This session's `.git` reads `gitdir: /workspaces/.dotfiles/.git/worktrees/drop-upgrade-path` -- absolute. Claude Code's native `--worktree` does not pass the flag, so worktrees it creates today would fail under `--mount-git-worktree-common-dir`.
- **`wt add` must always pass `--relative-paths`.** Confirmed available in the local git 2.55.0 (`--[no-]relative-paths  use relative paths for worktrees`); the flag landed in git 2.48, which sets the version floor.
- This is a **second, independent reason the `WorktreeCreate` shim must exist**: not just to choose the path, but to create the worktree correctly. Naming was the weaker argument; correctness is the strong one.
- It also resolves 5.2. Absolute paths in git metadata were the disease; relative paths make the worktree/repo pair relocatable, which is exactly what crossing the host/container mount boundary requires. The devcontainer CLI demands the cure we independently needed.

#### Verified: `worktree.useRelativePaths` solves this at the git layer

Confirmed empirically on the host (git 2.55.0, 2026-08-02):

| Case | Result |
|---|---|
| `git worktree add` (default) | `gitdir: /home/iggy/wtprobe/repo/.git/worktrees/wt-abs` -- absolute |
| `-c worktree.useRelativePaths=true`, **no flag** | `gitdir: ../repo/.git/worktrees/wt-cfg`; admin side `../../../../wt-cfg/.git` -- **relative** |
| `--relative-paths` flag | `gitdir: ../repo/.git/worktrees/wt-flag` -- relative, identical outcome |
| `worktree repair` with the config set | Converted the pre-existing absolute worktree in place: `gitdir: ../repo/.git/worktrees/wt-abs` |
| Relocating the whole tree | Survived |

Three consequences, and they simplify the design considerably:

1. **Config alone is sufficient.** Setting `worktree.useRelativePaths = true` in `git/.gitconfig` makes *every* worktree relocatable regardless of who created it -- Claude Code's native `--worktree`, Codex, a subagent, or a human running `git worktree add`. This is the harness-agnostic property we wanted, obtained from git itself rather than from wrapping each harness.
2. **Existing worktrees are migratable.** `git worktree repair` with the config set rewrites absolute pointers to relative in place, so worktrees Claude Code has already created do not need recreating.
3. **The `WorktreeCreate` shim is demoted.** It is no longer required for pointer correctness. It remains valuable for credential provisioning, slug and port allocation, and location choice -- but the property that must hold for *every* worktree, including ones created by tools we do not control, is now handled by git.

Note on the relocation test: the absolute worktree also survived the move, but only because step 4's `repair` had already converted it. That does not show absolute paths are relocatable; it shows `repair` works.

Caveats:

- **Version floor.** `--relative-paths` and this config landed in git 2.48. Ubuntu 20.04 (git 2.25) and Debian 11 (git 2.30) are below it. An unknown config key is silently ignored by older git, so the setting degrades gracefully -- but those platforms will produce absolute worktrees and cannot use `--mount-git-worktree-common-dir`. `wt doctor` must check the git version and say so plainly.
- **Relative means the pair must move together.** The worktree and its repo must keep their relative relationship. The nested layout guarantees this; a sibling layout at arbitrary paths does not.
- `wt add` should still pass `--relative-paths` explicitly as belt and braces, in case a repo-local config or a different `HOME` overrides the global setting.

Good news, verified against this repo: **none of `.devcontainer/{debian-bash,ubuntu-zsh,unattended}/devcontainer.json` sets `workspaceMount`**, so this repo is not exposed to [devcontainers/cli#1243](https://github.com/devcontainers/cli/issues/1243), where the common-dir mount is silently skipped when a custom `workspaceMount` is present. That bug becomes a rule `dc-audit` must enforce for other projects.

The alternative topology -- mount the repo root, create worktrees inside the container -- is rejected: it puts worktrees inside container storage, breaks VS Code opening a worktree directly, and breaks host-side agent editing.

**What still argues for nested**, after this retraction:

| Argument | Status |
|---|---|
| Devcontainer needs no config | **Void** under per-worktree containers (this section) |
| Host sandbox write scope | **Stronger** -- agent now runs host-tier with bwrap on, and nested worktrees are inside the workspace |
| Migration cost | Holds -- no re-clone |
| Claude Code `EnterWorktree` approval friction | Holds |

Net: still nested at `<repo>/.worktrees/<slug>/`, but now on sandbox and ergonomics grounds rather than devcontainer grounds.

### 3.4 Security upside: agent credentials never enter the container

With the agent on the host, the container is a pure build/test executor and never needs Claude Code, Codex, or Copilot credentials.
That is strictly better than today, where the agent runs in-container with its credentials mounted via the state volume.

The trade-off is scoped, not eliminated: a VS Code interactive session in a worktree may still want an agent *inside* the container, which reintroduces credentials there. Treat in-container agents as a distinct, opt-in profile rather than the default.

### 3.5 Personal state: split the volume by write pattern, not by worktree

r3 called the hardcoded state-volume names a straight collision defect. That was too blunt.
The volume exists to preserve **personal** state -- agentic tool credentials -- across container rebuilds, so *sharing across containers is the goal*, not the bug.

What is actually persisted (`bootstrap/symlinks.sh`, via `_wire_tool_dir` and `setup_volume_dir`):

| Path | Contents |
|---|---|
| `~/.claude` | credentials **and** session transcripts, history, project state |
| `~/.codex` | credentials and session state |
| `~/.copilot` | credentials and session state |
| `~/.config/gh`, `~/.config/glab-cli` | auth tokens |

The real hazard is not sharing per se; it is that each of these directories **mixes read-mostly credentials with append-heavy session state**.
Under per-worktree containers, N containers sharing one `~/.claude` means concurrent appends to transcripts, history, and `.claude.json`.
Credentials tolerate sharing well -- writes happen only at login or token refresh, and the worst case is re-authentication. Append-heavy session files do not.

**Recommended split:**

- **Identity tier** -- stable volume name, shared across all worktree containers: credentials only (`~/.claude/.credentials.json`, `~/.codex/auth.json`, `~/.config/gh`, `~/.config/glab-cli`). Read-mostly; sharing is intended.
- **Session tier** -- `${devcontainerId}`-scoped: transcripts, history, caches, `.claude.json`. Append-heavy; isolation prevents interleaved writes.

**The default path avoids the problem entirely.** Under section 3 the agent runs on the host with `~/.claude` on the host, so a worktree container needs no agent credentials at all.
The identity tier mounts only when the in-container agent profile is opted into (3.4).
That preserves the capability you want without paying the concurrency cost by default.

`dc-audit` should still flag fixed volume names, but as "verify this is intended sharing" rather than an outright collision error.

### 3.6 Dotfiles installation in CLI-launched containers is fully supported

The devcontainer CLI accepts the same dotfiles mechanism as the VS Code extension:

| Option | Default |
|---|---|
| `--dotfiles-repository` | none -- URL of the dotfiles git repository |
| `--dotfiles-install-command` | auto-detects the first of `install.sh`, `install`, `bootstrap.sh`, `bootstrap`, `setup.sh`, `setup` in the repo root |
| `--dotfiles-target-path` | `~/dotfiles` |

Accepted by `up`, `set-up`, and `run-user-commands` -- **not** by `build`.
This repo has `install.sh` at its root, so auto-detection works with no extra configuration.

Two design notes:

- These are **CLI flags, not `devcontainer.json` properties**. That is philosophically correct: personal dotfiles do not belong in a project's committed config. It also means the setting is per-invocation, so `wt` must supply it centrally -- a `wt`-level config value applied to every `wt container-up`, rather than something each project declares.
- Because `build` does not accept them, any pre-build/caching flow must not assume dotfiles are present at build time.

### 3.7 Cost model makes shared caches load-bearing

`devcontainer up` per worktree means image resolution plus dependency installation per worktree.
The design doc's section 7 split stops being an optimization and becomes the thing that makes this usable: share content-addressed download caches (npm/pnpm, pip/uv, cargo, go mod) via a stable named volume across worktree containers; keep mutable output (`node_modules/`, `target/`, `dist/`, `.venv/`) per worktree.

### 3.8 Decided: verification contract, lifecycle, credential delivery

#### `./dev verify` runs in the container, by definition

`./dev verify` is a **naming convention, not new functionality**. It is one stable entry point that runs the project's full pre-handoff verification -- for this repo, `make lint && make test`; elsewhere, lint plus typecheck plus tests plus generated-file consistency.

The value is that every project exposes the same verb, so agent instructions can say "run `./dev verify` before handoff" once, globally, instead of per project. Without it, agents reverse-engineer intent from `Makefile`, `package.json`, or CI config and get it subtly wrong -- running unit tests but not the lint gate, or a watch-mode command that never exits.

`./dev` is owned by each **project**, not by dotfiles. Dotfiles supplies only the convention and the instruction-file line.

This creates a two-tier verification split that must be stated explicitly, because agents will otherwise try to run `devcontainer` from inside a container:

| Command | Runs | Verifies |
|---|---|---|
| `./dev verify` | **in container** via `devcontainer exec` | project correctness: lint, types, tests, generated files |
| `wt doctor` | **on host** | environment correctness: worktree pointers, relative paths, port allocation, devcontainer CLI version, container health |

#### Lifecycle: `wt remove` tears down the worktree's containers

Decided: removing a worktree kills its containers.

Implementation constraint, confirmed against the CLI: **there is no `down`, `stop`, or `teardown` subcommand.** The only removal-adjacent option is `--remove-existing-container` on `up`. Teardown therefore goes through `docker` directly, and needs a reliable handle on "the containers belonging to this worktree".

`--id-label name=value` ("Id label(s) of the format name=value. These will be set on the container") is accepted by `up`, `run-user-commands`, `read-configuration`, and `exec`.
So `wt container-up` sets `--id-label wt.slug=<slug>`, and `wt remove` tears down by filtering on that label rather than guessing from container names or workspace paths.

Volumes are retained unless `--volumes` is passed explicitly, per the design doc's teardown rules.

#### Credential delivery: prefer `--remote-env` over mounting files

The historical reason for sharing whole `~/.claude`, `~/.codex`, and `~/.copilot` directories is sound and should be recorded: **named volumes can only mount directories -- only a bind mount can target a single file, and single-file bind mounts break under atomic rename** (write-temp-then-rename), which is exactly how OAuth token refresh rewrites a credentials file. Whole-directory volumes were the correct call.

`--remote-env name=value` ("Remote environment variables of the format name=value") is accepted by `up`, `set-up`, `run-user-commands`, and `exec`. That gives a file-free path: inject credentials at invocation time from the host, so nothing persists in container storage and the atomic-rename problem disappears.

Recommended split:

| Credential | Delivery | Confidence |
|---|---|---|
| `GH_TOKEN`, `GITLAB_TOKEN` | `--remote-env`, sourced from host | High -- documented env-var auth |
| Agent CLI credentials | directory volume, opt-in profile only | Env-var auth for the agent CLIs means an API key, which bypasses subscription OAuth. **Needs verification before assuming it is a drop-in replacement.** |

And the simplification that matters most: under section 3 the **default path needs none of this**, because the agent runs on the host and the container is a pure executor.

### 3.9 Open questions for this model

- **File ownership on bind mounts.** `updateRemoteUserUID` is unset in all three variants (defaults on for Linux). Host-agent writes and container writes must not fight over ownership. Needs a Phase 1 check on Linux/WSL2 and macOS.
- **Agent CLI env-var auth.** Whether subscription-based auth can be delivered without a credentials file (3.8).

## 4. Layout decision

**`<repo>/.worktrees/<slug>/` -- nested, vendor-neutral, with Claude Code redirected there by a dotfiles-shipped `WorktreeCreate` hook.**

Rationale in 3.3 (sandbox, migration, friction) plus: `.claude/` is a vendor namespace, and Codex or Copilot worktrees living under it is indefensible when Codex has no native support at all.
`.claude/` also holds settings, agents, and commands -- mixing configuration with checkouts is a category error.

Costs of nesting and mitigations: recursive tools and Docker build contexts see repo copies (gitignore `.worktrees/`, `.dockerignore`, `dc-audit` check); editor indexing (`files.watcherExclude`); deleting the repo deletes its worktrees (`wt remove` is the supported path).

**Residual risk.** `WorktreeCreate` aborts creation on non-zero exit, making `wt` a single point of failure where it is missing or broken.
The shim must **degrade** -- fall back to `git worktree add "$worktree_base_path/$worktree_suffix"` -- and exit non-zero **only** when ignore-validation rejects a destination, where aborting is correct. This distinction gets a test.

### 4.1 Reconciliation with the existing `wt` shell function (PR #80)

Discovered at execution time: `shell/functions.sh:444-497` already ships a `wt` function (merged 2026-08-01, PR #80) that creates **sibling** worktrees at `<parent>/<repo>-worktrees/<leaf>`, cd's into them, and defaults the base to `origin/HEAD` matching Claude Code's `worktree.baseRef=fresh`. PR #80 also added sandbox `excludedCommands` for `git worktree *` / `git checkout *` to permit sibling-directory writes (currently being reworked in uncommitted local changes).

Its header comment argues *for* siblings on three hazards of nesting. Assessed:

- **`git clean -fdx` in the parent deletes nested worktrees** -- **disproven** (dry-run test, 2026-08-02): git skips nested repositories, and a worktree's `.git` file counts (`Would skip repository .worktrees/feat`). Only a deliberate double-force `git clean -ffdx` removes them.
- **Node upward module resolution** -- **stands**. A nested worktree missing its own `node_modules` silently resolves imports to the parent checkout's `node_modules`. Real hazard for host-side work in Node projects; does not apply in per-worktree containers (deps installed in-container per worktree) and does not apply to sibling layouts.
- **Watcher/crawler noise (tsc, jest, eslint)** -- partial. Tools that honour gitignore are fine; tools with their own include globs need `.worktrees/` excludes (already a Phase 5/6 item).

Resolution path for Phase 3, in order of preference:

1. Keep the nested decision; mitigate Node resolution by having `wt add` verify the worktree installs its own deps before host-side toolchain use (or simply document that host-side Node work uses the container). Update the `wt` function to the nested layout and fold it into `bin/wt`.
2. If Node resolution proves disqualifying in practice, re-run the devcontainer mount-topology spike (section 9) against a *sibling* relative-path worktree before switching: the CLI's mount reconstruction was only verified for the nested case, and sibling relocatability requires the repo and worktree tree to move together, which sibling directories do not guarantee.

Either way the existing function's UX (create + cd, `origin/HEAD` default, leaf-name slugging) carries into `bin/wt`, and the superseded header comment gets corrected -- its `git clean` claim is wrong for worktrees.

**Open sub-decision.** `local/` and `state/` must sit outside every checkout, hence outside the sandbox workspace under any layout.
Proposal: `${XDG_DATA_HOME:-~/.local/share}/wt/<project-id>/{local,state}/`, decided deliberately against `docs/future-workspace-local-state.md` so AI-tool state and project local-dev state do not silently merge.

## 5. Repo-specific findings

### 5.1 The stale `core.hooksPath` is orphaned installer cruft

```
file:/workspaces/.dotfiles/git/.gitconfig    ~/.config/git/hooks
file:/workspaces/.dotfiles/.git/config       /home/iggy/.dotfiles/.git/hooks
```

The repo-local value wins; `/home/iggy/.dotfiles/.git/hooks` does not exist in the container. Git does not error on a missing hooks path, it runs no hooks -- so gitleaks and commit-msg enforcement are inert here.

Root cause: **the current `install.sh` does not set this.** `bootstrap/symlinks.sh:479` symlinks `git/hooks` to `~/.config/git/hooks`; `git/.gitconfig:10` points `core.hooksPath` there. The absolute-path form came from historical installers (`70159e3`, `db4e292`) and survives every rebuild because `.git/` is in the bind mount. The current design is correct; the artifact was never cleaned up.

### 5.2 Absolute paths in git metadata cross the host/container boundary badly

`.git/config`, each worktree's `.git` file, and `.git/worktrees/<n>/gitdir` all store **absolute** paths.
A repo at `/workspaces/x` in a container and `/home/iggy/x` on the host has two truths for the same files.

This is now more acute, not less: under section 3 the **host** creates worktrees and the **container** consumes them. Create on host, open in container, and the pointer is wrong -- which is why `git worktree repair` exists.
`wt doctor` must detect divergence and offer `git worktree repair`, and `wt` must never write host-absolute paths into shared git metadata.

### 5.3 Reuse the existing hook escape-hatch convention

`git/hooks/pre-commit` already delegates to a repo-local hook before running gitleaks. That is the pattern for `post-checkout`: one global hook delegating to `post-checkout.local` plus the provisioning helper.
**No project ever sets `core.hooksPath`** -- the design doc's section 9 advice would override the global path and silently disable secret scanning, precisely the failure in 5.1.

Correction to carry over: in a linked worktree `git rev-parse --git-dir` returns the per-worktree admin dir, not the shared repo (verified: `--git-dir` -> `.git/worktrees/drop-upgrade-path`, `--git-common-dir` -> `.git`). Repo-local hooks are a property of the repository, so resolve via `--git-common-dir`. `pre-commit` has the same latent bug.

### 5.4 `dc-audit` has no mount-related rules yet

`bin/dc-audit.sh` currently has no checks for `workspaceMount`, `docker.sock`, `privileged`, or `mounts`. Every rule in Phase 4 is genuinely new.

## 6. Ownership split

| Dotfiles | Project |
|---|---|
| `wt` command surface and library | `.dev/worktree.conf` (no secrets) |
| devcontainer CLI installation and version floor | `.devcontainer/` spec |
| global `post-checkout` provisioning hook | `.gitignore` entries for local paths |
| `WorktreeCreate`/`WorktreeRemove` shims in `settings.json` | `compose.yaml` |
| ignore-validation enforcement | `./dev verify`, defined as in-container |
| port/slug allocation, registry, `wt doctor` | `AGENTS.md` scope and handoff rules |

Dotfiles tooling must never weaken a repository's ignore rules, credential scope, or cleanup protections to make worktree creation succeed.

## 7. Phased implementation

Each phase is independently shippable, and carries tests -- merges gate on `make lint` and `make test`.

### Phase 0 -- land the doc, fix the orphaned hooks path

- Commit `docs/agentic-worktree-dev-environment.md`, amended for the nested vendor-neutral layout (4), the `core.hooksPath` reversal (5.3), the `.worktreeinclude` correction (2.2), and the host/container execution model (3).
- Remove the stale repo-local `core.hooksPath` (5.1).
- Fix `pre-commit` to resolve repo-local hooks via `--git-common-dir` (5.3).
- `tests/validate-dotfiles.sh`: assert the effective `core.hooksPath` resolves to an existing directory.
- **Set `worktree.useRelativePaths = true` in `git/.gitconfig`** (3.3). Verified, one line, and it makes every worktree relocatable no matter which harness created it -- the single highest-leverage change in this plan. Ships independently of everything else.
- Document `git worktree repair` as the migration path for worktrees already created with absolute pointers.

### Phase 1 -- spikes

Verification before construction. The execution model adds most of these.

- ~~Per-worktree `devcontainer up` with `--mount-git-worktree-common-dir`~~ **Done** -- verified working, mount topology recorded in 3.3.
- Complete the in-container **write** test with an explicit git identity; the first attempt aborted on unknown author before reaching the object store (3.3).
- Git version floor across supported platforms: Ubuntu 20.04 and Debian 11 ship git below 2.48 and cannot produce relative worktrees (3.3). Decide whether that demotes them to host-only worktree use.
- Host/container path divergence and `git worktree repair` (5.2).
- Host bwrap/Seatbelt: what breaks writing to the proposed `local/`/`state/` root, given git-writes-to-`.git` are permitted (2.2). Decide narrow allowance vs `excludedCommands`.
- `devcontainer *` under bwrap -- confirm it needs the `excludedCommands` exemption (3.2).
- Bind-mount file ownership between host-agent writes and container writes (3.9).
- Does the ad-hoc `EnterWorktree` tool route through `WorktreeCreate`? The hook docs list `--worktree`, subagent isolation, background, and desktop sessions -- not `EnterWorktree`; the tools-reference page does not settle it either. Test empirically: configure a `WorktreeCreate` hook that appends to a log file, ask Claude mid-session to "work in a worktree", and check whether the log line appears. If it bypasses, mid-session worktrees skip provisioning and the `post-checkout` hook is their only coverage -- which the design already provides, so the answer changes documentation, not architecture.
- Output: findings appended to `docs/sandbox.md`.

### Phase 2 -- host toolchain

Packaging differs per platform. Checked 2026-08-02:

| Platform | Availability | Approach |
|---|---|---|
| macOS | **Homebrew formula `devcontainer` exists** in homebrew/core (v0.88.0, MIT, depends on `node`) | Add to the existing `install_brew` formula list. Gets Homebrew's verification and upgrade management for free. |
| Debian / Ubuntu | **Not in apt.** No Debian or Ubuntu package | Standalone install script (bundles its own Node.js), or the GitHub release tarball through the existing `_verify_checksum` path. Prefer the latter if the release assets carry checksums -- confirm. |
| Alpine / musl | Not packaged; the standalone installer's bundled Node.js is glibc-linked and will likely fail | **Not needed.** See scope note below. |

**Scope note:** the devcontainer CLI runs on the **host** (macOS, Linux/WSL2). Alpine appears in this repo's matrix as a *container* platform, not a dev host, and containers never launch containers under this architecture. Gate the install on `is_devcontainer()` being false, which removes the musl portability gap entirely rather than solving it.

**macOS trade-off worth a deliberate choice:** the brew formula depends on Homebrew's `node`, so `brew install devcontainer` puts a Node on the host -- a managed dependency under the brew prefix, not a project toolchain, so it does not really violate the section 3.1 goal. The standalone script's bundled Node is invisible by comparison but self-managed. Either is defensible; brew is more consistent with how this repo already installs macOS tooling.

- Record a minimum version floor of 0.81.0 for worktree common-dir mounting (brew currently ships 0.88.0), and have `wt doctor` assert it.

### Phase 3 -- `wt` core

- `bin/wt` plus `bootstrap/lib/wt/*.sh`, following the existing `bin/` + `bootstrap/lib/` split.
- Commands: `add`, `list`, `path`, `sync`, `diff-local`, `remove`, `prune`, `doctor`.
- **`wt add` always passes `git worktree add --relative-paths`** (3.3). Non-negotiable: `--mount-git-worktree-common-dir` does not work without it. Git version floor 2.48.
- Slug normalization, collision checks, transactional `add` with rollback.
- `local/shared` (overwrite) and `local/template` (`--ignore-existing`) provisioning.
- **Ignore validation before any copy** -- `git check-ignore -q` per destination, hard-fail on a non-ignored path. The security invariant; tested first.
- Port/slug registry with `flock`, atomic-`mkdir` fallback on macOS.
- `wt doctor`: path divergence (5.2), devcontainer CLI version floor, port uniqueness, stale registry entries.
- Constraints: bash 3.2-compatible, no GNU-only flags, shellcheck-clean, Alpine/musl-safe.
- `tests/test-wt.sh`, wired into `Makefile` and CI.

### Phase 4 -- harness integration

Delivers harness-agnosticism.

- `WorktreeCreate` shim: reads stdin JSON, calls `wt add`, prints the path. **Degrades to plain `git worktree add` when `wt` is unavailable; exits non-zero only on ignore-validation failure** (4).
- `WorktreeRemove` shim: calls `wt remove`, best-effort, never blocks cleanup.
- Both into `claude-code/settings.json`, regenerated via `make sync-settings`, covered by `bin/settings-drift.sh`.
- Add `devcontainer *` to `excludedCommands` (3.2).
- Global `git/hooks/post-checkout`: fires only on initial checkout (null old ref, kind 1), idempotent, never overwrites customized template files, never starts containers or installs dependencies, warns rather than failing ordinary git use, delegates via `--git-common-dir`.
  This is what covers Codex CLI, Copilot CLI, and hand-rolled `git worktree add`.
- Tests: null-ref detection, idempotency, ignore-validation failure, and the degrade-vs-abort distinction.

### Phase 5 -- container orchestration

- `wt container-up` / `wt exec` wrapping `devcontainer up` / `devcontainer exec --workspace-folder <worktree>`, with `--mount-git-worktree-common-dir`.
- Supply `--dotfiles-repository` (and target path) centrally from `wt` config so every worktree container gets the user's dotfiles, matching VS Code behaviour (3.6).
- Split the state volume into identity and session tiers; mount the identity tier only under the opt-in in-container agent profile (3.5).
- Per-worktree runtime identity: generated `.env.worktree` with slug, `COMPOSE_PROJECT_NAME`, database name, cache namespace, allocated ports.
- Shared download-cache volumes, isolated build output (3.7).
- Teardown: `wt container-up` stamps `--id-label wt.slug=<slug>`; `wt remove` tears down matching containers via `docker` (the CLI has no `down`/`stop` subcommand), retaining volumes unless `--volumes` (3.8).
- Credential delivery via `--remote-env` for `GH_TOKEN`/`GITLAB_TOKEN`; agent CLI creds stay on the directory volume under the opt-in in-container profile (3.8).
- Extend `bin/dc-audit.sh`: flag custom `workspaceMount` as worktree-hostile (3.3), fixed `container_name` and globally-named volumes/networks as collision risks (3.5), missing `.worktrees/` exclusion.
- Extend `tests/test-dc-audit.sh`.

### Phase 6 -- instruction files

- `claude-code/CLAUDE.md`, `codex/AGENTS.md`, `copilot/copilot-instructions.md`: short parallel sections -- one agent per worktree, where worktrees live, **run builds and tests via `devcontainer exec`, never on the host**, `./dev verify` as the handoff gate. Must stay short; always-on context.
- Root `AGENTS.md`/`CLAUDE.md`: `wt` maintenance context, following the deny-list-semantics precedent.
- `templates/worktree-project/`: `.dev/worktree.conf.example`, recommended `.gitignore` entries, `post-checkout.local` example, worktree-compatible `.devcontainer/`.
- Mark `unattended/planning/ralph-worktree-infrastructure.md` Part 1 as superseded by this plan. No migration of the ralph stack: it is slated for deprecation in a separate later step and carries no compatibility requirement (1.1).

## 8. Open questions

1. `local/`/`state/` location and its relationship to `docs/future-workspace-local-state.md` (4). Maintainer is open to revisiting, with the hard boundary that Codespaces persistence must keep working (1.1) -- note that in Codespaces, workspace-local storage outlives volumes on full rebuild, which may argue for a workspace-adjacent location there.
2. Credential profiles (`--profile no-secrets`) in Phase 3, or defer until a second consumer?
3. Proving ground: this repo has no `compose.yaml`, so Phase 5 needs a real project.
4. Sandbox concession if the Phase 1 spike shows the state root is blocked.
5. In-container agents as an opt-in profile for VS Code interactive work (3.4) -- worth supporting, or explicitly out of scope?

## 9. Appendix: Phase 1 spike protocol -- worktree git inside a per-worktree container

**Executed 2026-08-02. Result: pass.** Findings recorded in 3.3; the script is kept here as a regression check for CLI upgrades. Must run on the **host**; a devcontainer has no Docker access.

The question it answered: a nested worktree's relative pointer is `gitdir: ../../.git/worktrees/feat`, so the CLI had either to mount the common dir at `/.git` or to mount the workspace deeper to preserve the relative relationship. It does the latter -- worktree at `/workspaces/.worktrees/feat`, common dir at `/workspaces/.git`.

```bash
# prerequisites: git >= 2.48, devcontainer CLI >= 0.81.0
command -v devcontainer ||
  curl -fsSL https://raw.githubusercontent.com/devcontainers/cli/main/scripts/install.sh | sh
export PATH="$HOME/.devcontainers/bin:$PATH"

# scratch repo, minimal devcontainer, deliberately NO custom workspaceMount
mkdir -p ~/wtprobe3/repo/.devcontainer && cd ~/wtprobe3/repo
git init -q && git config worktree.useRelativePaths true
printf '{\n  "name": "wt-probe",\n  "image": "mcr.microsoft.com/devcontainers/base:ubuntu"\n}\n' \
  > .devcontainer/devcontainer.json
git add -A && git commit -q --no-verify -m devcontainer

# nested worktree, relative paths -- the proposed layout
git worktree add -q .worktrees/feat
cat .worktrees/feat/.git            # expect: gitdir: ../../.git/worktrees/feat

# CONTROL: without the flag, in-container git should fail
devcontainer up --workspace-folder ~/wtprobe3/repo/.worktrees/feat --id-label wtprobe=ctl
devcontainer exec --workspace-folder ~/wtprobe3/repo/.worktrees/feat --id-label wtprobe=ctl \
  -- git status --short && echo "CONTROL: worked (unexpected)" || echo "CONTROL: failed (expected)"

# TEST: with the flag
devcontainer up --workspace-folder ~/wtprobe3/repo/.worktrees/feat --id-label wtprobe=test \
  --mount-git-worktree-common-dir
devcontainer exec --workspace-folder ~/wtprobe3/repo/.worktrees/feat --id-label wtprobe=test \
  --mount-git-worktree-common-dir -- bash -lc '
    echo "toplevel:   $(git rev-parse --show-toplevel)"
    echo "common-dir: $(git rev-parse --path-format=absolute --git-common-dir)"
    git status --short; git worktree list
    git commit -q --allow-empty -m write-test && echo "WRITE OK" || echo "WRITE FAILED"'

# what did the CLI actually mount?
docker inspect --format '{{json .Mounts}}' \
  "$(docker ps -q --filter label=wtprobe=test)" | jq .

# teardown -- also validates the --id-label handle wt remove will use (3.8)
docker rm -f $(docker ps -aq --filter label=wtprobe)
```

Pass criteria: `--show-toplevel` and `--git-common-dir` both resolve, `status` and `worktree list` succeed, and the empty commit **writes** to the shared `.git`.

## 10. Session evidence log (2026-08-02)

Compact record of every fact this plan rests on, with how it was established, so future sessions do not re-derive or (worse) re-assume them. "Host test" = run by the maintainer on the WSL2 host; "container test" = run in this repo's devcontainer session; "source" = upstream docs or code read directly.

### Verified by test

| Fact | How |
|---|---|
| `worktree.useRelativePaths=true` alone (no flag) produces relative pointers both directions (`gitdir: ../repo/.git/worktrees/wt-cfg` / `../../../../wt-cfg/.git`) | Host test, git 2.55.0 |
| `git worktree repair` with that config converts existing absolute worktrees in place; idempotent; prints "absolute/relative path mismatch" per conversion | Host test |
| Relative worktrees survive relocating the whole tree | Host test (absolute-survival result contaminated by prior repair -- shows repair works, not that absolute survives) |
| `devcontainer up` without common-dir flag: in-container git fails `fatal: not a git repository: (null)` | Host test, CLI 0.88.0 |
| With `--mount-git-worktree-common-dir`: two binds, worktree at `/workspaces/.worktrees/feat`, common dir at `/workspaces/.git` -- relative structure reconstructed, not flattened; `toplevel`/`common-dir`/`status`/`worktree list` all resolve | Host test |
| In-container `git commit` aborts on unknown author identity -- CLI does not copy host `.gitconfig` (VS Code extension does). Write-to-object-store still unconfirmed | Host test, pending identity-injected rerun |
| CLI auto-builds an `updateUID.Dockerfile` variant aligning container UID with host user (Linux) | Host test output |
| Nested worktree inside the *repo-root* mount: git fully works in-container with zero config | Container test -- this session |
| In a linked worktree, `--git-dir` returns the per-worktree admin dir; `--git-common-dir` returns the shared `.git` | Container test |
| Repo-local `core.hooksPath=/home/iggy/.dotfiles/.git/hooks` overrides the global value and does not exist in-container; hooks silently inert; current `install.sh` does not write it (historical commits `70159e3`, `db4e292` did) | Container test + git history |
| This container has no docker CLI, no socket, no devcontainer CLI, no node -- consistent with executor-only containers | Container test |

### Established from source

| Fact | Source |
|---|---|
| Claude Code worktrees: default `.claude/worktrees/<name>/`, branch `worktree-<name>`; `EnterWorktree` prompts outside that dir (v2.1.206+, only `bypassPermissions` skips); refuses symlinked `.claude`/worktree paths; sandbox allows git writes to shared `.git`; `.worktreeinclude` copies matching+gitignored files; `worktree.baseRef` fresh/head; plugins and permission approvals shared from main checkout | code.claude.com/docs/en/worktrees |
| `WorktreeCreate` replaces creation logic entirely (may relocate); receives `worktree_base_path`+`worktree_suffix` on stdin; prints path; non-zero exit **aborts**; fires on `--worktree`, subagent isolation, background, desktop -- `EnterWorktree` not listed. `WorktreeRemove` side-effect-only, cannot block. `.worktreeinclude` **not** processed when hook present | code.claude.com/docs/en/hooks |
| devcontainer CLI: `--mount-git-worktree-common-dir` on up/exec/build/etc., description says **requires `--relative-paths` worktrees**; `--dotfiles-repository`/`--dotfiles-install-command` (auto-detects `install.sh` etc.)/`--dotfiles-target-path` on up/set-up/run-user-commands, **not build**; `--id-label` on up/exec; `--remote-env` on up/set-up/run-user-commands/exec; **no down/stop subcommand**; only `--remove-existing-container` on up | devContainersSpecCLI.ts |
| Flag silently ignored under custom `workspaceMount` (none of this repo's three variants set one -- verified locally) | devcontainers/cli#1243, vscode-remote-release#11478 |
| devcontainers/cli publishes **no GitHub releases**; installer pulls nodejs.org + `registry.npmjs.org/@devcontainers/cli/-/cli-<v>.tgz` with **no verification**; bundles Node; `~/.devcontainers`; Linux/macOS only | releases page + install.sh |
| Homebrew formula `devcontainer` exists in core, v0.88.0, depends on `node`; no apt package for Debian/Ubuntu | formulae.brew.sh API |
| Codex CLI has no worktree support (desktop app does) -- openai/codex#12862 open; Copilot CLI none | GitHub + search |
| `--relative-paths` / `worktree.useRelativePaths` landed in git 2.48; Ubuntu 20.04 (2.25) and Debian 11 (2.30) below floor | git release notes + distro versions |

### Repo facts a future session needs

- `.gitignore:10` ignores `.claude/`; `.worktrees/` is **not yet ignored**.
- State volume: `_wire_tool_dir` persists whole `~/.claude`, `~/.codex`, `~/.copilot`; plus `gh`/`glab-cli` config dirs (`bootstrap/symlinks.sh`). Whole-directory choice is deliberate: named volumes cannot mount single files, and single-file binds break under the atomic rename OAuth refresh performs.
- Three devcontainer variants hardcode state-volume names (`dotfiles-<variant>-state`); intentional personal-state sharing, not a defect (3.5).
- `bin/dc-audit.sh` has no mount-related rules yet; `bootstrap/packages.sh` has `_verify_checksum`/`_select_checksum_url` machinery; hook escape-hatch pattern is `pre-commit` delegating to `$(git rev-parse --git-dir)/hooks/pre-commit.local` (latent `--git-dir` bug, 5.3).
- Host `settings.json` sandbox: `excludedCommands` = `gh *`, `glab *`, `docker *`; `sandbox.credentials` denies `~/.git-credentials`, `~/.config/gh`, `~/.dotfiles-state` among others -- Class B forwarding must not route through them.
- This session ran as: devcontainer, user `vscode`, repo bind-mounted at `/workspaces/.dotfiles`, session in nested worktree `.claude/worktrees/drop-upgrade-path` on branch `worktree-drop-upgrade-path` (pre-existing unrelated commit `1c06543`).

## 11. Non-goals

No production credentials to agents, no shared mutable build output, no automatic merge or publish of agent work, no replacement of project-owned devcontainer/Compose/build configuration, no attempt to make submodules reliable across concurrent worktrees.
