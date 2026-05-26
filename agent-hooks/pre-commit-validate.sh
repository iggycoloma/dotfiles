#!/usr/bin/env bash
# Pre-tool commit hook -- intentional no-op preview.
#
# Earlier versions of this hook tried to parse `git commit ...` command
# strings to validate the message at PreToolUse time. The parser only
# handled `-m "..."` and one heredoc shape; `-F /path/to/msg`,
# `--file=...`, `-t /path/to/template`, and non-EOF heredoc markers all
# slipped through and silently allowed. That is a misleading contract
# for an apparent guardrail.
#
# The authoritative validator is the git commit-msg hook at
# git/hooks/commit-msg, wired globally via core.hooksPath. It reads the
# real message file after git has resolved every input shape (-m, -F,
# --file, -t, editor, heredoc), so coverage is uniform. See
# tests/test-commit-msg-hook.sh for behavioral coverage.
#
# This hook still drains stdin and exits 0 so the wrapper protocol
# (Codex needs a clean exit code) keeps working. Adding a partial
# pre-flight check here is tempting but would re-create the same
# "looks like a gate, actually isn't" failure mode.

cat >/dev/null
exit 0
