#!/usr/bin/env bash
# Tests for bin/exec-modes.sh.
#
# The script resolves its repo from its own location rather than DOTFILES_DIR,
# so a fixture cannot just point an env var at a temp tree: each case builds a
# throwaway git repo, copies the script (and the logging.sh it sources) into
# the same relative layout, and commits blobs with known index modes.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR_REAL="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECKER="$DOTFILES_DIR_REAL/bin/exec-modes.sh"

source "$SCRIPT_DIR/test-framework.sh"

# A minimal repo carrying the script under bin/ so its SCRIPT_DIR/.. resolves
# to the fixture, never to this checkout.
setup_fixture() {
    local tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/bin" "$tmp/bootstrap"
    cp "$CHECKER" "$tmp/bin/exec-modes.sh"
    cp "$DOTFILES_DIR_REAL/bootstrap/logging.sh" "$tmp/bootstrap/logging.sh"
    git -C "$tmp" init -q
    git -C "$tmp" config user.email "test@example.com"
    git -C "$tmp" config user.name "Test"
    git -C "$tmp" config commit.gpgsign false
    git -C "$tmp" add -A
    # --no-verify: the fixture must not depend on whatever global
    # core.hooksPath the developer running the suite has installed.
    git -C "$tmp" commit -qm init --no-verify
    printf '%s' "$tmp"
}

# ---------------------------------------------------------------------------

test_suite "exec-modes: syntax + executable"

bash -n "$CHECKER" 2>/dev/null
assert_return_code 0 $? "exec-modes.sh passes bash -n"
if [[ -x "$CHECKER" ]]; then
    test_pass "exec-modes.sh is executable"
else
    test_fail "exec-modes.sh is executable"
fi

# ---------------------------------------------------------------------------

test_suite "exec-modes: this repo is clean"

out=$("$CHECKER" 2>&1)
assert_return_code 0 $? "the repo's own tracked modes all pass"
assert_contains "$out" "all" "reports a clean result"

# ---------------------------------------------------------------------------

test_suite "exec-modes: detects a shebang file missing +x"

tmp=$(setup_fixture)
printf '#!/usr/bin/env bash\necho hi\n' > "$tmp/bin/runme.sh"
git -C "$tmp" add bin/runme.sh
git -C "$tmp" update-index --chmod=-x -- bin/runme.sh
out=$("$tmp/bin/exec-modes.sh" 2>&1)
rc=$?
assert_return_code 1 $rc "exits nonzero when an entry point lacks +x"
assert_contains "$out" "bin/runme.sh" "names the offending file"
assert_contains "$out" "not executable" "explains the direction of the mismatch"

# --fix repairs it, and the repaired tree then passes.
"$tmp/bin/exec-modes.sh" --fix >/dev/null 2>&1
assert_equals "100755" "$(git -C "$tmp" ls-files -s -- bin/runme.sh | awk '{print $1}')" \
    "--fix sets the index mode to 100755"
"$tmp/bin/exec-modes.sh" >/dev/null 2>&1
assert_return_code 0 $? "repaired tree passes"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "exec-modes: detects a non-entry-point carrying +x"

tmp=$(setup_fixture)
printf 'not a script\n' > "$tmp/bin/notes.txt"
git -C "$tmp" add bin/notes.txt
git -C "$tmp" update-index --chmod=+x -- bin/notes.txt
out=$("$tmp/bin/exec-modes.sh" 2>&1)
rc=$?
assert_return_code 1 $rc "exits nonzero on a stray +x"
assert_contains "$out" "notes.txt" "names the offending file"
"$tmp/bin/exec-modes.sh" --fix >/dev/null 2>&1
assert_equals "100644" "$(git -C "$tmp" ls-files -s -- bin/notes.txt | awk '{print $1}')" \
    "--fix clears the stray bit"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "exec-modes: sourced libraries stay non-executable"

# bootstrap/ is on the NON_EXEC list, so a shebang there must NOT demand +x --
# this is the rule that stops "every .sh gets +x" from creeping back in.
tmp=$(setup_fixture)
printf '#!/usr/bin/env bash\nhelper() { :; }\n' > "$tmp/bootstrap/helper.sh"
git -C "$tmp" add bootstrap/helper.sh
git -C "$tmp" update-index --chmod=-x -- bootstrap/helper.sh
"$tmp/bin/exec-modes.sh" >/dev/null 2>&1
assert_return_code 0 $? "a shebang under bootstrap/ is not required to be executable"

git -C "$tmp" update-index --chmod=+x -- bootstrap/helper.sh
"$tmp/bin/exec-modes.sh" >/dev/null 2>&1
assert_return_code 1 $? "and is rejected when it gains +x"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

test_suite "exec-modes: reads the index, not the working tree"

# The gate must survive an installer that chmods a checkout mid-CI, so a
# working-tree mode that disagrees with the index must not change the verdict.
tmp=$(setup_fixture)
printf '#!/usr/bin/env bash\necho hi\n' > "$tmp/bin/runme.sh"
chmod +x "$tmp/bin/runme.sh"
git -C "$tmp" add bin/runme.sh
# Index now says 100755; drop the bit on disk only. The verdict must follow
# the index, which is what makes the gate immune to an installer's chmod.
chmod -x "$tmp/bin/runme.sh"
"$tmp/bin/exec-modes.sh" >/dev/null 2>&1
assert_return_code 0 $? "a working-tree chmod does not fail the check"
rm -rf "$tmp"

# ---------------------------------------------------------------------------

print_test_summary
