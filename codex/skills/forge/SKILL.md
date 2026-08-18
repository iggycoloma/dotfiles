---
name: forge
description: Forge interaction conventions for GitHub and GitLab. Use before drafting or editing a PR/MR description, issue, or forge comment, or when deciding between gh/glab subcommands and raw api calls.
metadata:
  short-description: PR/MR and forge writing conventions
---

# Forge

The canonical conventions live in `~/.codex/prompts/forge.md`, deployed from dotfiles `agent-prompts/forge.md`.

## How to Run This Skill

1. Read `~/.codex/prompts/forge.md` in full -- it is not loaded by default, so read the file rather than working from memory.
2. Apply it: purpose-built `gh`/`glab` subcommands over raw `api` calls, no hard-wrapping in forge bodies, and the description shape (Summary / What changed / Safety and compatibility / Testing / Known follow-up).
3. Follow the publication policy in `~/.codex/AGENTS.md`: draft forge text for the human to post unless posting was explicitly granted for the task.
