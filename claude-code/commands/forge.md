---
description: |
  Load the forge interaction conventions: gh/glab subcommand preference over
  raw api calls, forge body formatting (no hard-wrapping), and the PR/MR
  description shape. TRIGGER when drafting or editing a PR/MR description,
  issue, or forge comment, or when choosing between gh/glab subcommands and
  gh api / glab api. SKIP inside review-pr or pr-create -- both load the
  fragment themselves.
allowed-tools: Read
---

Read `~/.claude/prompts/forge.md` in full and apply it to the forge task at hand.
It is the canonical statement of these conventions and is not loaded by default, so read the file rather than working from memory.

The outward-facing-writes policy still applies: compose forge text, show it, and stop.
Do not run `gh pr create`, `glab mr create`, or their `comment` / `review` / `note` / `approve` equivalents.
