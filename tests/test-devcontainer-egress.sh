#!/usr/bin/env bash
# Tests for bootstrap/devcontainer-egress.sh -- gating logic only.
# (Rule installation needs NET_ADMIN + a controlled netns; out of scope here.)

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$DOTFILES_DIR/bootstrap/devcontainer-egress.sh"

source "$SCRIPT_DIR/test-framework.sh"

# Sanity.

test_suite "devcontainer-egress: syntax + executable"

bash -n "$SCRIPT" 2>/dev/null
assert_return_code 0 $? "devcontainer-egress.sh passes bash -n syntax check"

if [[ -x "$SCRIPT" ]]; then
    test_pass "devcontainer-egress.sh is executable"
else
    test_fail "devcontainer-egress.sh is executable"
fi

# Gating: each negative gate must short-circuit with exit 0 and a log message
# so the script is safe to keep wired into install.sh unconditionally.
#
# Run via env -i to strip the inherited DOTFILES_*/REMOTE_*/CODESPACES vars
# (so the script's own gates are what's being tested, not whatever state
# this CI runner happens to expose).

test_suite "devcontainer-egress: gating logic"

# Gate 1: DOTFILES_DEVCONTAINER_EGRESS unset -> skip.
out=$(env -i HOME="$HOME" PATH="$PATH" bash "$SCRIPT" 2>&1)
rc=$?
assert_equals 0 "$rc" "exits 0 when DOTFILES_DEVCONTAINER_EGRESS unset"
assert_contains "$out" "DOTFILES_DEVCONTAINER_EGRESS not set" \
    "logs the gate-1 skip reason"

# Gate 2: opted in but not in a devcontainer -> skip.
out=$(env -i HOME="$HOME" PATH="$PATH" \
    DOTFILES_DEVCONTAINER_EGRESS=1 \
    bash "$SCRIPT" 2>&1)
rc=$?
# Note: env -i removes REMOTE_CONTAINERS / CODESPACES, but is_devcontainer
# also checks /.dockerenv as a sentinel. In a real devcontainer the sentinel
# is present, so the gate will pass to gate 3+. Accept either outcome but
# require exit 0 and a logged reason for any skip that does happen.
assert_equals 0 "$rc" "exits 0 when only DOTFILES_DEVCONTAINER_EGRESS=1 set"
if [[ -f /.dockerenv ]]; then
    test_pass "container sentinel present -- gate 2 passes (expected in this env)"
else
    assert_contains "$out" "not in a devcontainer" \
        "logs the gate-2 skip reason on a host"
fi

# Gate 3: opted in + sentinel + DOTFILES_NO_AI_TOOLS=1 -> skip.
# is_devcontainer is sourced via detect.sh; the sentinel check makes this
# deterministic inside the test container.
if [[ -f /.dockerenv ]]; then
    out=$(env -i HOME="$HOME" PATH="$PATH" \
        DOTFILES_DEVCONTAINER_EGRESS=1 \
        DOTFILES_NO_AI_TOOLS=1 \
        bash "$SCRIPT" 2>&1)
    rc=$?
    assert_equals 0 "$rc" "exits 0 when DOTFILES_NO_AI_TOOLS=1"
    assert_contains "$out" "DOTFILES_NO_AI_TOOLS=1" \
        "logs the gate-3 skip reason"
fi

# Allowlist sanity: the embedded host list must include the core endpoints
# (Anthropic + GitHub + at least one registry per language). Catches
# accidental deletion when editing.

test_suite "devcontainer-egress: allowlist sanity"

assert_command_succeeds "allowlist includes api.anthropic.com" \
    grep -q "api.anthropic.com" "$SCRIPT"
assert_command_succeeds "allowlist includes github.com" \
    grep -q "github.com" "$SCRIPT"
assert_command_succeeds "allowlist includes registry.npmjs.org" \
    grep -q "registry.npmjs.org" "$SCRIPT"
assert_command_succeeds "allowlist includes pypi.org" \
    grep -q "pypi.org" "$SCRIPT"
assert_command_succeeds "allowlist includes crates.io" \
    grep -q "crates.io" "$SCRIPT"
assert_command_succeeds "allowlist includes proxy.golang.org" \
    grep -q "proxy.golang.org" "$SCRIPT"

# --- Summary ---

print_test_summary
