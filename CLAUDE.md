@AGENTS.md

# Claude-Specific Instructions

Model-neutral policy for this repository is canonical in `AGENTS.md`, imported above.
The deny-list semantics for `claude-code/settings.json` and command frontmatter live in `.claude/rules/deny-list-semantics.md`,
a path-scoped rule that loads only when files matching `claude-code/settings*.json` or `claude-code/commands/**` are being read or edited.
No extra response calibration is needed here -- the deployed `~/.claude/CLAUDE.md` already carries it globally.
