#!/usr/bin/env bash
# Tests for bin/settings-drift.sh.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR_REAL="$(cd "$SCRIPT_DIR/.." && pwd)"
DRIFT="$DOTFILES_DIR_REAL/bin/settings-drift.sh"

source "$SCRIPT_DIR/test-framework.sh"

# Build a temp dotfiles layout with synthetic settings/config pairs we can
# tweak per test, then point the script at it via DOTFILES_DIR.
setup_fixture() {
    local tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/claude-code" "$tmp/codex" "$tmp/bootstrap"
    # Vendor logging.sh so the script can source it without the real repo.
    cp "$DOTFILES_DIR_REAL/bootstrap/logging.sh" "$tmp/bootstrap/logging.sh"
    printf '%s' "$tmp"
}

# ---------------------------------------------------------------------------

test_suite "settings-drift: syntax + executable"

bash -n "$DRIFT" 2>/dev/null
assert_return_code 0 $? "settings-drift.sh passes bash -n"
if [[ -x "$DRIFT" ]]; then
    test_pass "settings-drift.sh is executable"
else
    test_fail "settings-drift.sh is executable"
fi

# ---------------------------------------------------------------------------

test_suite "settings-drift: real repo files in sync"

# The repo's own variant pairs should pass after Slice 1 + Slice 2.
out=$("$DRIFT" 2>&1)
rc=$?
assert_equals 0 "$rc" "exits 0 when repo variants are in sync"
assert_contains "$out" "all variants in sync" "logs in-sync summary"

# ---------------------------------------------------------------------------

test_suite "settings-drift: claude-code drift detection"

tmp=$(setup_fixture)
# Host variant: a non-sandbox key present.
cat > "$tmp/claude-code/settings.json" <<'JSON'
{
  "permissions": {"allow": ["Read", "Bash(git status:*)"]},
  "sandbox": {"enabled": true}
}
JSON
# Container variant: same key but a different value (drift).
cat > "$tmp/claude-code/settings.container.json" <<'JSON'
{
  "permissions": {"allow": ["Read"]},
  "sandbox": {"enabled": false}
}
JSON
# Codex pair: in sync (only sandbox_mode differs).
cat > "$tmp/codex/config.toml" <<'TOML'
sandbox_mode = "workspace-write"
approval_policy = "on-request"
TOML
cat > "$tmp/codex/config.container.toml" <<'TOML'
sandbox_mode = "danger-full-access"
approval_policy = "on-request"
TOML

out=$(DOTFILES_DIR="$tmp" "$DRIFT" 2>&1)
rc=$?
assert_equals 1 "$rc" "exits 1 on claude-code drift"
assert_contains "$out" "claude-code: drift detected" "names the drifting pair"
assert_contains "$out" "Bash(git status:*)" "diff shows the missing entry"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "settings-drift: codex drift detection"

tmp=$(setup_fixture)
# Claude pair: in sync.
cat > "$tmp/claude-code/settings.json" <<'JSON'
{"permissions": {"allow": ["Read"]}, "sandbox": {"enabled": true}}
JSON
cat > "$tmp/claude-code/settings.container.json" <<'JSON'
{"permissions": {"allow": ["Read"]}, "sandbox": {"enabled": false}}
JSON
# Codex pair: deliberate drift on approval_policy.
cat > "$tmp/codex/config.toml" <<'TOML'
sandbox_mode = "workspace-write"
approval_policy = "on-request"
TOML
cat > "$tmp/codex/config.container.toml" <<'TOML'
sandbox_mode = "danger-full-access"
approval_policy = "never"
TOML

out=$(DOTFILES_DIR="$tmp" "$DRIFT" 2>&1)
rc=$?
assert_equals 1 "$rc" "exits 1 on codex drift"
assert_contains "$out" "codex: drift detected" "names the drifting pair"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "settings-drift: sandbox-only differences are ignored"

tmp=$(setup_fixture)
# Claude: only sandbox differs (allowed). The deny list is present and in
# parity so this fixture exercises the host-vs-container check alone.
cat > "$tmp/claude-code/settings.json" <<'JSON'
{
  "permissions": {
    "allow": ["Read", "Write"],
    "deny": ["Read(a)", "Write(a)", "Edit(a)"]
  },
  "hooks": {"PreToolUse": [{"matcher": "Bash"}]},
  "sandbox": {
    "enabled": true,
    "network": {"allowedDomains": ["api.anthropic.com"]}
  }
}
JSON
cat > "$tmp/claude-code/settings.container.json" <<'JSON'
{
  "permissions": {
    "allow": ["Read", "Write"],
    "deny": ["Read(a)", "Write(a)", "Edit(a)"]
  },
  "hooks": {"PreToolUse": [{"matcher": "Bash"}]},
  "sandbox": {"enabled": false}
}
JSON
# Codex: only sandbox_mode differs.
cat > "$tmp/codex/config.toml" <<'TOML'
sandbox_mode = "workspace-write"
approval_policy = "on-request"
TOML
cat > "$tmp/codex/config.container.toml" <<'TOML'
sandbox_mode = "danger-full-access"
approval_policy = "on-request"
TOML

out=$(DOTFILES_DIR="$tmp" "$DRIFT" 2>&1)
rc=$?
assert_equals 0 "$rc" "exits 0 when only sandbox sections differ"
assert_contains "$out" "in sync" "logs in-sync result"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "settings-drift: key order is insensitive"

tmp=$(setup_fixture)
# Same content, keys in different order.
cat > "$tmp/claude-code/settings.json" <<'JSON'
{"sandbox": {"enabled": true}, "permissions": {"allow": ["Read", "Write"], "deny": ["Read(a)", "Write(a)", "Edit(a)"]}}
JSON
cat > "$tmp/claude-code/settings.container.json" <<'JSON'
{"permissions": {"deny": ["Read(a)", "Write(a)", "Edit(a)"], "allow": ["Read", "Write"]}, "sandbox": {"enabled": false}}
JSON
# Skip codex (use real repo via symlinks would complicate; just point to
# valid in-sync codex stubs).
cat > "$tmp/codex/config.toml" <<'TOML'
sandbox_mode = "workspace-write"
TOML
cat > "$tmp/codex/config.container.toml" <<'TOML'
sandbox_mode = "danger-full-access"
TOML

out=$(DOTFILES_DIR="$tmp" "$DRIFT" 2>&1)
rc=$?
assert_equals 0 "$rc" "exits 0 when only key order differs"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "settings-drift: missing variant is treated as drift"

tmp=$(setup_fixture)
# Only host variant present -- the deletion form of drift.
cat > "$tmp/claude-code/settings.json" <<'JSON'
{"sandbox": {"enabled": true}}
JSON
cat > "$tmp/codex/config.toml" <<'TOML'
sandbox_mode = "workspace-write"
TOML

out=$(DOTFILES_DIR="$tmp" "$DRIFT" 2>&1)
rc=$?
assert_equals 1 "$rc" "exits 1 when a variant is missing (deletion bug)"
assert_contains "$out" "container variant missing" "logs the missing-variant reason"
rm -rf "$tmp"

# Symmetric case: host missing.
tmp=$(setup_fixture)
cat > "$tmp/claude-code/settings.container.json" <<'JSON'
{"sandbox": {"enabled": false}}
JSON
cat > "$tmp/codex/config.container.toml" <<'TOML'
sandbox_mode = "danger-full-access"
TOML

out=$(DOTFILES_DIR="$tmp" "$DRIFT" 2>&1)
rc=$?
assert_equals 1 "$rc" "exits 1 when host variant is missing"
assert_contains "$out" "host variant missing" "logs the missing-variant reason"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "settings-drift: --json output"

tmp=$(setup_fixture)
cat > "$tmp/claude-code/settings.json" <<'JSON'
{"permissions": {"allow": ["A"]}, "sandbox": {"enabled": true}}
JSON
cat > "$tmp/claude-code/settings.container.json" <<'JSON'
{"permissions": {"allow": ["B"]}, "sandbox": {"enabled": false}}
JSON
cat > "$tmp/codex/config.toml" <<'TOML'
sandbox_mode = "workspace-write"
TOML
cat > "$tmp/codex/config.container.toml" <<'TOML'
sandbox_mode = "danger-full-access"
TOML

out=$(DOTFILES_DIR="$tmp" "$DRIFT" --json 2>&1)
rc=$?
assert_equals 1 "$rc" "exits 1 on drift in --json mode"
# Each line should be a valid JSON object.
while IFS= read -r line; do
    if [[ -n "$line" ]] && ! jq -e . <<<"$line" >/dev/null 2>&1; then
        test_fail "non-JSON line in --json output: $line"
        break
    fi
done <<< "$out"
test_pass "every --json line parses as JSON"

# Verify the drifting pair appears with status=drift.
if printf '%s\n' "$out" | jq -e 'select(.pair == "claude-code" and .status == "drift")' >/dev/null 2>&1; then
    test_pass "--json reports claude-code as drifted"
else
    test_fail "--json reports claude-code as drifted"
fi
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "settings-drift: Read/Write/Edit deny parity"

# A synthetic pair whose only interesting content is the deny list. The
# container variant mirrors the host so class-1 drift never fires and we are
# only exercising the parity check.
parity_fixture() {
    local deny_json="$1" tmp
    tmp=$(setup_fixture)
    jq -n --argjson deny "$deny_json" \
        '{permissions: {allow: ["Read"], deny: $deny}, sandbox: {enabled: true}}' \
        > "$tmp/claude-code/settings.json"
    jq '.sandbox = {"enabled": false}' "$tmp/claude-code/settings.json" \
        > "$tmp/claude-code/settings.container.json"
    cat > "$tmp/codex/config.toml" <<'TOML'
sandbox_mode = "workspace-write"
TOML
    cat > "$tmp/codex/config.container.toml" <<'TOML'
sandbox_mode = "danger-full-access"
TOML
    printf '%s' "$tmp"
}

# Baseline: three identical blocks in identical order.
tmp=$(parity_fixture '["Read(a)","Read(b)","Write(a)","Write(b)","Edit(a)","Edit(b)"]')
out=$(DOTFILES_DIR="$tmp" "$DRIFT" 2>&1)
rc=$?
assert_equals 0 "$rc" "exits 0 when the three deny blocks match"
assert_contains "$out" "deny lists in parity" "logs the parity pass"
rm -rf "$tmp"

# A path denied for Read and Write but forgotten in Edit -- the bug this check
# exists to catch, since Edit is a write path just like Write.
tmp=$(parity_fixture '["Read(a)","Read(b)","Write(a)","Write(b)","Edit(a)"]')
out=$(DOTFILES_DIR="$tmp" "$DRIFT" 2>&1)
rc=$?
assert_equals 1 "$rc" "exits 1 when a path is missing from Edit"
assert_contains "$out" "out of parity" "names the parity failure"
assert_contains "$out" "only in Write" "reports which block holds the orphan"
rm -rf "$tmp"

# Same membership, different order. Order carries meaning here: the blocks are
# maintained side by side, so a reorder means someone appended to one only.
# jq's array `-` is set difference and reports nothing for a pure reorder, so
# assert the message actually names the diverging entries -- a message that
# merely says "differs" is unactionable on a 130-line list.
tmp=$(parity_fixture '["Read(a)","Read(b)","Write(b)","Write(a)","Edit(b)","Edit(a)"]')
out=$(DOTFILES_DIR="$tmp" "$DRIFT" 2>&1)
rc=$?
assert_equals 1 "$rc" "exits 1 when blocks share members but differ in order"
assert_contains "$out" "different order" "identifies the failure as a reordering"
assert_contains "$out" "index 0" "names the first diverging index"
assert_contains "$out" "Write/Edit has b" "names the entry on the write side"
assert_contains "$out" "Read has a" "names the entry on the read side"
assert_not_contains "$out" "[]" "does not emit empty set-difference brackets"
rm -rf "$tmp"

# The declared Write/Edit-only exemption must not be reported.
tmp=$(parity_fixture '["Read(a)","Write(a)","Write(~/.claude/projects/*/memory/**)","Edit(a)","Edit(~/.claude/projects/*/memory/**)"]')
out=$(DOTFILES_DIR="$tmp" "$DRIFT" 2>&1)
rc=$?
assert_equals 0 "$rc" "exits 0 for the declared Write/Edit-only exemption"
rm -rf "$tmp"

# An *undeclared* Write/Edit-only path is still a finding -- the exemption list
# is an allowlist, not a blanket pass for Read-side omissions.
tmp=$(parity_fixture '["Read(a)","Write(a)","Write(~/.config/undeclared/**)","Edit(a)","Edit(~/.config/undeclared/**)"]')
out=$(DOTFILES_DIR="$tmp" "$DRIFT" 2>&1)
rc=$?
assert_equals 1 "$rc" "exits 1 for an undeclared Write/Edit-only path"
assert_contains "$out" "undeclared" "names the offending path in the message"
rm -rf "$tmp"

# A deleted permissions.deny[] must FAIL, not skip. This is the regression the
# whole check exists to catch, and routing it through a non-fatal skip would let
# CI merge a settings.json with every credential rule removed.
tmp=$(setup_fixture)
jq -n '{permissions: {allow: ["Read"]}, sandbox: {enabled: true}}' \
    > "$tmp/claude-code/settings.json"
jq '.sandbox = {"enabled": false}' "$tmp/claude-code/settings.json" \
    > "$tmp/claude-code/settings.container.json"
cat > "$tmp/codex/config.toml" <<'TOML'
sandbox_mode = "workspace-write"
TOML
cat > "$tmp/codex/config.container.toml" <<'TOML'
sandbox_mode = "danger-full-access"
TOML
out=$(DOTFILES_DIR="$tmp" "$DRIFT" 2>&1)
rc=$?
assert_equals 1 "$rc" "exits 1 when permissions.deny[] is missing entirely"
assert_contains "$out" "must never be absent" "explains why a missing deny list is fatal"
assert_not_contains "$out" "all variants in sync" "does not claim success"
rm -rf "$tmp"

# An empty deny array is the same regression wearing a different hat.
tmp=$(parity_fixture '[]')
out=$(DOTFILES_DIR="$tmp" "$DRIFT" 2>&1)
rc=$?
assert_equals 1 "$rc" "exits 1 when permissions.deny[] is present but empty"
rm -rf "$tmp"

# --json mode carries the parity result too.
tmp=$(parity_fixture '["Read(a)","Write(a)","Edit(a)","Edit(b)"]')
out=$(DOTFILES_DIR="$tmp" "$DRIFT" --json 2>&1)
if printf '%s\n' "$out" | jq -e 'select(.check == "deny-parity" and .status == "drift")' >/dev/null 2>&1; then
    test_pass "--json reports deny-parity drift"
else
    test_fail "--json reports deny-parity drift"
fi
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "sync-settings: container variant is generated, not hand-edited"

SYNC="$DOTFILES_DIR_REAL/bin/sync-settings.sh"

bash -n "$SYNC" 2>/dev/null
assert_return_code 0 $? "sync-settings.sh passes bash -n"
if [[ -x "$SYNC" ]]; then
    test_pass "sync-settings.sh is executable"
else
    test_fail "sync-settings.sh is executable"
fi

# The committed container variant must already match what the generator emits.
out=$("$SYNC" --check 2>&1)
rc=$?
assert_equals 0 "$rc" "committed settings.container.json matches the generator"

# A hand-edit to the container variant is caught by --check.
tmp=$(setup_fixture)
cp "$DOTFILES_DIR_REAL/claude-code/settings.json" "$tmp/claude-code/settings.json"
jq '.sandbox = {"enabled": false} | .permissions.allow += ["Bash(hand-edited:*)"]' \
    "$tmp/claude-code/settings.json" > "$tmp/claude-code/settings.container.json"
out=$(DOTFILES_DIR="$tmp" "$SYNC" --check 2>&1)
rc=$?
assert_equals 1 "$rc" "exits 1 when the container variant was hand-edited"
assert_contains "$out" "stale" "tells the user to re-run the generator"
rm -rf "$tmp"

# Generating into a fixture reproduces the host file with the container sandbox.
tmp=$(setup_fixture)
cp "$DOTFILES_DIR_REAL/claude-code/settings.json" "$tmp/claude-code/settings.json"
DOTFILES_DIR="$tmp" "$SYNC" >/dev/null 2>&1
rc=$?
assert_equals 0 "$rc" "generates the container variant"
assert_equals 'false' "$(jq -r '.sandbox.enabled' "$tmp/claude-code/settings.container.json")" \
    "generated variant disables the sandbox"
assert_equals '1' "$(jq -r '.sandbox | keys | length' "$tmp/claude-code/settings.container.json")" \
    "generated variant carries no other sandbox keys"
assert_equals \
    "$(jq -cS 'del(.sandbox)' "$tmp/claude-code/settings.json")" \
    "$(jq -cS 'del(.sandbox)' "$tmp/claude-code/settings.container.json")" \
    "generated variant matches the host on every non-sandbox key"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

print_test_summary
