# Worktree project template

Files a project adopts to work with the `wt` orchestration layout
(see `docs/agentic-worktree-dev-environment.md` and `bin/wt`).

| File | Copy to | Purpose |
|------|---------|---------|
| `worktree.conf.example` | `.dev/worktree.conf` (tracked) | project id and port range for `.env.worktree` generation |
| `gitignore.snippet` | append to `.gitignore` | required ignore entries; `wt` refuses to provision non-ignored destinations |
| `post-checkout.local.example` | `<repo>/.git/hooks/post-checkout.local` (per-machine, executable) | repo-specific hook the global post-checkout delegates to |
| `devcontainer.json.example` | `.devcontainer/devcontainer.json` (tracked) | worktree-compatible container spec (no custom workspaceMount, devcontainerId-scoped volumes) |

Initialize a project:

```bash
wt init git@github.com:org/example.git ~/code/example
cd ~/code/example
wt add issue-123        # creates wt/issue-123, provisions local/, allocates a port
wt container-up issue-123
wt exec issue-123 -- ./dev verify
```

Machine-local files go under `~/code/example/local/`:
`shared/` is refreshed into worktrees by `wt sync` (overwrites),
`template/` is copied only when a file is absent (worktree-customizable).
Every destination must be gitignored by the project or provisioning fails.

Optional lifecycle hooks live in `local/hooks/` (user-owned, never sourced from the checkout):
`post-add` runs once after a new worktree is provisioned,
`post-sync` after every re-provision.
Each receives the worktree path as `$1`; a failing hook warns but never fails the command.
