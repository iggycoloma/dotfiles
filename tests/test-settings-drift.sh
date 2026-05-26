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
# Claude: only sandbox differs (allowed).
cat > "$tmp/claude-code/settings.json" <<'JSON'
{
  "permissions": {"allow": ["Read", "Write"]},
  "hooks": {"PreToolUse": [{"matcher": "Bash"}]},
  "sandbox": {
    "enabled": true,
    "network": {"allowedDomains": ["api.anthropic.com"]}
  }
}
JSON
cat > "$tmp/claude-code/settings.container.json" <<'JSON'
{
  "permissions": {"allow": ["Read", "Write"]},
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
{"sandbox": {"enabled": true}, "permissions": {"allow": ["Read", "Write"]}}
JSON
cat > "$tmp/claude-code/settings.container.json" <<'JSON'
{"permissions": {"allow": ["Read", "Write"]}, "sandbox": {"enabled": false}}
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

print_test_summary
