# Quickstart: Devcontainer Support

## Local devcontainer with state persistence

Add the following to your `devcontainer.json`:

```json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
  "remoteUser": "vscode",
  "mounts": [
    "source=${devcontainerId}-state,target=/home/vscode/.dotfiles-state,type=volume"
  ],
  "postCreateCommand": "bash /workspaces/.dotfiles/install.sh"
}
```

Open the project in VS Code; the container builds, the volume is created (or reused if it already exists for this devcontainerId), and `install.sh` wires up state persistence.

What survives across rebuilds:
- Claude Code authentication (`~/.claude/.credentials.json`)
- Codex CLI authentication (`~/.codex/`)
- GitHub CLI auth (`~/.config/gh/hosts.yml`)
- Atuin shell history database
- Claude Code session state (sessions/, plans/)

What refreshes each boot:
- `~/.claude/settings.json`, `CLAUDE.md`, hooks, agents, commands
- `~/.codex/AGENTS.md`, skills/
- `~/.copilot/copilot-instructions.md`

## GitHub Codespaces

No configuration needed.
Open a Codespace from any repo with the dotfiles installed via VS Code's "Dotfiles: Repository" setting.
State persistence auto-uses `/workspaces/.codespaces/.persistedshare/dotfiles-state/`.

## Verifying state persistence

After install, run:

```bash
ls -la ~/.dotfiles-state
```

You should see (depending on what you've used):

```
drwx------ 6 vscode vscode 4096 May  8 10:00 .
drwxr-x--- 1 vscode vscode 4096 May  8 10:00 ..
drwx------ 5 vscode vscode 4096 May  8 10:00 claude
drwx------ 3 vscode vscode 4096 May  8 10:00 codex
drwx------ 2 vscode vscode 4096 May  8 10:00 copilot
drwx------ 2 vscode vscode 4096 May  8 10:00 gh
```

And `dotfiles-doctor` should report green.

## Skipping state persistence

If you want pure ephemeral state (e.g. for a CI container that should have no persistent credentials):

```json
{
  "remoteEnv": {
    "DOTFILES_NO_STATE_PERSISTENCE": "1"
  }
}
```

The installer will skip all volume / persistedshare detection.
Each container start gets fresh `~/.claude`, `~/.codex` directories with no auth state.

## Troubleshooting

### Volume mount appears but state still doesn't persist

Check ownership: the volume may be root-owned on first mount.
The installer chowns to the current user, but if the chown fails (no sudo), state writes will fail silently.

```bash
ls -la ~/.dotfiles-state
sudo chown -R "$(id -u):$(id -g)" ~/.dotfiles-state
chmod 700 ~/.dotfiles-state
```

### Codespaces persistedshare not writable

Falls back to ephemeral with a warning in the install log.
Your Codespace should be able to write to `/workspaces/.codespaces/ .persistedshare/`; if it can't, contact GitHub support.

### Claude/Codex re-prompting for auth after rebuild

Your tier may have unexpectedly become ephemeral (e.g. volume mount was removed from devcontainer.json).
Run `dotfiles-doctor` and check the State Persistence section to see which tier is active.

### Where can I see the recommended mount snippet?

Run `./install.sh` in a local devcontainer that lacks the volume mount.
The installer logs the snippet near the end of the install output.
