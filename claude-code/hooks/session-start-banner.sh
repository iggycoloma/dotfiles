#!/usr/bin/env bash
# SessionStart hook - print a reminder banner.
#
# Prints a stricter banner when CLAUDE_UNATTENDED=1 so the agent knows it is
# running without a human in the loop and should behave more conservatively.

if [[ "${CLAUDE_UNATTENDED:-0}" == "1" ]]; then
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
    exit 0
fi

echo "Reminder: no emojis in code or commits. Use conventional commits. Never read .env or credential files. Do not add AI attribution or Co-Authored-By to commits. Prefer: ast-grep (sg) for structural search, difft for diffs, sd for find/replace, scc for code stats, yq for YAML/TOML editing."
