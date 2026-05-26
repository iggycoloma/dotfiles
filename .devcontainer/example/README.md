# Devcontainer Example

`devcontainer.json` in this directory is a reference template. Copy it into
your own project's `.devcontainer/` to get the dotfiles environment with
persistent state across container rebuilds.

```bash
mkdir -p .devcontainer
cp ~/.dotfiles/.devcontainer/example/devcontainer.json .devcontainer/
```

Then:

1. Replace `"repository": "yourusername/.dotfiles"` with your fork.
2. (Optional) uncomment `--cap-add=NET_ADMIN` in `runArgs` and set
   `DOTFILES_DEVCONTAINER_EGRESS=1` in `remoteEnv` to enable the iptables
   egress allowlist. See [`../../docs/sandbox.md`](../../docs/sandbox.md)
   for what it does.
3. (Recommended) configure dotfiles repo + install command in VS Code User
   Settings instead of inside `devcontainer.json` -- the in-file `dotfiles`
   property is a VS Code-only extension, not part of the spec.

## What this gives you

The example template includes:

- **One shared state volume** (`source=${devcontainerId}-state,target=/home/vscode/.dotfiles-state,type=volume`)
  -- persists Claude Code, Codex, Copilot CLI, and shell history across
  rebuilds. See [`../../docs/architecture.md#state-persistence`](../../docs/architecture.md#state-persistence)
  for the tiered persistence model.
- **All dotfiles toggles documented** as commented-out `remoteEnv` entries
  you can flip on as needed. See
  [`../../docs/customization.md#installation-toggles`](../../docs/customization.md#installation-toggles)
  for the full list.
- **Egress allowlist opt-in** -- see the comments in the example for the
  one-line opt-in pattern.

## Updating dotfiles in a running container

```bash
cd ~/.dotfiles && git pull && ./install.sh
```

`install.sh` is re-runnable. Configs refresh from the dotfiles repo; state
(auth tokens, sessions, shell history) in the volume is preserved.

## Reset to fresh configuration

To wipe the persisted state (sign out of all CLIs, lose shell history):

```bash
docker volume rm <devcontainerId>-state
# Then rebuild the container.
```
