# Worktrees (parallel agent work)

Operational rules for the `wt` worktree system, shared across tools.

Two related rules deliberately live elsewhere.
The prohibition on repo-local `core.hooksPath` sits in each tool's Guardrails: it silently disables global secret scanning, so it is inlined per tool rather than loaded from here.
Publication policy is per-tool, because what an agent may push or open without asking differs between them.

- One agent per worktree, never two agents editing one checkout.
- Worktrees are managed exclusively by `wt`, which resolves the repo by walking up from the working directory, never down -- from a workspace root, run it from inside the target repo (`(cd <repo> && wt add <name>)`), then work in the printed path via absolute paths. Never re-root the session with a harness's built-in worktree isolation tool (Claude Code's EnterWorktree, or equivalents); where the WorktreeCreate shim is deployed it reroutes such calls through `wt` as a safety net, but the subshell-plus-absolute-paths flow is the supported path.
- Create with `wt add <name>` (prints the path); tear down with `wt remove <name>` -- it kills the worktree's containers, releases its ports, and refuses dirty trees. Never `rm -rf` a worktree.
- A nonzero exit from `add` does not mean nothing was created: a failing `post-add` hook keeps the worktree and reports the failure, so read the printed path and fix forward rather than retrying into `already exists`.
- The command surface documents itself -- `wt --help` and `wt <command> --help` are generated from one table, so read them rather than working from memory. `add`, `list`, `doctor` and `version` take `--json` when you want structured output instead of log lines.
- Layouts are auto-detected: an orchestration dir (bare `repo.git` + `local/` + `state/` + `wt/`) provisions local dev files and `.env.worktree`; a plain clone gets a sibling `<repo>-worktrees/` tree.
- Run project builds and tests in the project's dev container -- `wt container exec <name> -- <command>` from the host -- and keep the host toolchain-free. When the project provides `./dev verify`, it is the pre-handoff gate.
- Reach for a worktree for any task expected to produce commits; quick reads and answers need none. One task, one worktree, one branch -- never switch branches inside a worktree, and never touch another worktree's files.
- In an orchestration dir, `main/` is for review and integration only -- never develop there.
- Every worktree is a full checkout, so a search rooted above them scales with worktree count and can overrun the argv limit. `wt init` writes an `.ignore` at the orchestration root and `wt doctor` flags it missing or stale; `wt ignore [path]` backfills one for a project that predates this. One file per orchestration dir is enough even when the session is rooted further up -- rg reads ignore files at each level as it descends. Never expand a recursive glob (`**`, `*/*/*`) at a workspace root: ignore files do not apply to shell globs, so stream with `rg --files | xargs` or `fd -X` instead.
- Start by checking `wt sync --diff <name>` and rerun without `--diff` if local files drifted; hand off by committing everything, running `./dev verify` in the container, and leaving the worktree in place for review rather than removing it.
