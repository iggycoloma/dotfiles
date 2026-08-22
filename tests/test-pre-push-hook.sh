#!/usr/bin/env bash
# Contract tests for the global pre-push dispatcher.

set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-framework.sh"

HOOK="$DOTFILES_DIR/git/hooks/pre-push"
test_suite "pre-push hook structure"
bash -n "$HOOK"
assert_return_code 0 $? "pre-push passes bash -n"
assert_contains "$(cat "$HOOK")" "git lfs pre-push" "pre-push preserves Git LFS"
assert_contains "$(cat "$HOOK")" "pre-push.local" "pre-push delegates repository policy"
assert_contains "$(cat "$HOOK")" "gitleaks git" "pre-push scans outgoing commits"
assert_contains "$(cat "$HOOK")" "--redact" "pre-push redacts detected secrets"

print_test_summary
