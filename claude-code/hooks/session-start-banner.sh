#!/usr/bin/env bash
# SessionStart hook - print an unattended-mode banner.
#
# Attended sessions get nothing: the always-loaded ~/.claude/CLAUDE.md already
# carries the guardrail reminders verbatim, and instructions are re-loaded
# after compaction, so an attended banner only duplicated context. The
# unattended banner stays because it states rules CLAUDE.md does not.

[[ "${CLAUDE_UNATTENDED:-0}" == "1" ]] || exit 0

cat <<'EOF'
Reminder (UNATTENDED MODE): no human is reviewing each step. Prefer the smallest
change that closes the task. Run tests after every change. If a test fails,
revert and document the failure in progress.txt rather than pushing through.
After any dependency install, run the matching audit (npm audit, pip-audit,
cargo audit, govulncheck) and record the result. Never commit secrets or
generated credentials. Do not write outside the worktree. No emojis in code or
commits. Use conventional commits. Never read .env or credential files. Do not
add AI attribution or Co-Authored-By to commits.
EOF
