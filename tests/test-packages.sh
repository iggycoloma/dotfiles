#!/usr/bin/env bash
# Tests for packages.sh: _tool_config, _install_tool, run_sudo
set -u

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/tests/test-framework.sh"
source "$DOTFILES_DIR/bootstrap/detect.sh"
source "$DOTFILES_DIR/bootstrap/logging.sh"

# Source only the helper functions from packages.sh (not the full install flow)
source "$DOTFILES_DIR/bootstrap/packages.sh"

# ============================================================
# Test Suite: _tool_config
# ============================================================
test_suite "_tool_config"

# Test known tools return 0 and set pattern
_tool_config starship
assert_contains "$_tc_pattern" "starship" "starship pattern contains tool name"
assert_equals "tar.gz" "$_tc_format" "starship format is tar.gz"
assert_equals "standard" "$_tc_checksum" "starship checksum is standard"

_tool_config yq
assert_equals "binary" "$_tc_format" "yq format is binary (bare download)"
assert_equals "bsd" "$_tc_checksum" "yq checksum is bsd"
assert_equals "arm64" "$_tc_arch_remap" "yq remaps aarch64 to arm64"
assert_equals "amd64" "$_tc_x86_remap" "yq remaps x86_64 to amd64"

_tool_config watchexec
assert_equals "tar.xz" "$_tc_format" "watchexec format is tar.xz"
assert_equals "sha256sums" "$_tc_checksum" "watchexec checksum is sha256sums"

_tool_config sg
assert_equals "zip" "$_tc_format" "sg format is zip"
assert_equals "none" "$_tc_checksum" "sg has no checksum"
assert_equals "unknown-linux-gnu" "$_tc_os_override" "sg forces gnu"

_tool_config lazygit
assert_equals "true" "$_tc_skip_musl" "lazygit skips musl"
assert_equals "arm64" "$_tc_arch_remap" "lazygit remaps aarch64 to arm64"
assert_equals "lazygit" "$_tc_api_fallback" "lazygit has API fallback"

_tool_config zoxide
assert_equals "-maxdepth 3" "$_tc_find_depth" "zoxide uses find -maxdepth 3"

_tool_config difft
assert_equals "none" "$_tc_checksum" "difft has no checksum"
assert_equals "musl_fallback_gnu" "$_tc_os_override" "difft falls back musl to gnu"

_tool_config scc
assert_equals "arm64" "$_tc_arch_remap" "scc remaps aarch64 to arm64"

_tool_config bottom
assert_equals "btm" "$_tc_binary_name" "bottom binary name is btm"

_tool_config sd
assert_equals "none" "$_tc_checksum" "sd has no checksum"

_tool_config codex
assert_contains "$_tc_pattern" "codex" "codex pattern contains tool name"
assert_equals "none" "$_tc_checksum" "codex has no checksum (uses sigstore)"

# Test get_github_repo for codex
assert_equals "openai/codex" "$(get_github_repo codex)" "codex maps to openai/codex"

# Test all known tools have a non-empty pattern
for tool in starship eza zoxide delta lazygit atuin sd sg difft scc yq watchexec bottom codex; do
    _tool_config "$tool"
    assert_not_equals "" "$_tc_pattern" "$tool has a non-empty pattern"
done

# Test unknown tool returns 1
if _tool_config "nonexistent_tool" 2>/dev/null; then
    test_fail "unknown tool should return 1"
else
    test_pass "unknown tool returns 1"
fi

# ============================================================
# Test Suite: run_sudo
# ============================================================
test_suite "run_sudo"

# Skip the sudo tests when the container enforces `no-new-privileges` --
# sudo cannot escalate there by design, which is the whole point of the
# hardened devcontainer profile. Non-skip is detected by probing sudo once.
if sudo -n true 2>/dev/null; then
    # Test run_sudo executes command correctly
    output=$(run_sudo echo "hello world")
    assert_equals "hello world" "$output" "run_sudo passes through command output"

    # Test run_sudo preserves exit codes
    if run_sudo false 2>/dev/null; then
        test_fail "run_sudo should propagate failure exit code"
    else
        test_pass "run_sudo propagates failure exit code"
    fi
else
    test_pass "run_sudo tests skipped (sudo unavailable in this sandbox)"
fi

# ============================================================
# Test Suite: _install_tool (mocked)
# ============================================================
test_suite "_install_tool (mocked downloads)"

# Test that _install_tool rejects unknown tools
if _install_tool "nonexistent" "{}" "foo/bar" "/tmp" "x86_64" "unknown-linux-musl" 2>/dev/null; then
    test_fail "_install_tool should fail for unknown tool"
else
    test_pass "_install_tool fails for unknown tool"
fi

# Test that lazygit is skipped on musl
output=$(_install_tool "lazygit" "{}" "jesseduffield/lazygit" "/tmp" "x86_64" "unknown-linux-musl" 2>&1)
assert_contains "$output" "musl" "lazygit skip message mentions musl"

# ============================================================
# Test Suite: install-once gating
# ============================================================
test_suite "install-once gating"

# Every tool is install-once, agentic CLIs included: `codex update` and
# `claude update` own staying current. A reintroduced upgrade path would
# re-download on every run and burn the unauthenticated GitHub API budget
# (60/hour), so no per-tool upgrade opt-in should exist.
assert_not_contains "$(declare -f install_from_github)" "_tc_upgrade" \
    "install_from_github carries no upgrade opt-in"
assert_not_contains "$(declare -f install_claude_code)" "claude update" \
    "install_claude_code does not self-invoke claude update"

# ============================================================
# Test Suite: devcontainer CLI install gating
# ============================================================
test_suite "devcontainer CLI install gating"

# Host-only: containers never launch containers, so the function must
# bail before any download when running inside one.
assert_contains "$(declare -f install_devcontainer_cli)" "is_devcontainer" \
    "install_devcontainer_cli gates on is_devcontainer"

# In-container invocation is a silent no-op (no download, no log noise)
is_devcontainer() { return 0; }
output=$(install_devcontainer_cli 2>&1)
assert_equals "" "$output" "install_devcontainer_cli is a no-op inside containers"
unset -f is_devcontainer

# Install-once like every other tool; no upgrade path
assert_not_contains "$(declare -f install_devcontainer_cli)" "--update" \
    "install_devcontainer_cli carries no upgrade opt-in"

# brew formula on macOS, upstream installer elsewhere
assert_contains "$(declare -f install_devcontainer_cli)" "brew install devcontainer" \
    "install_devcontainer_cli uses the Homebrew formula when brew is the package manager"
assert_contains "$(declare -f install_devcontainer_cli)" "devcontainers/cli/main/scripts/install.sh" \
    "install_devcontainer_cli falls back to the upstream installer script"

# ============================================================
# Test Suite: git version floor
# ============================================================
test_suite "git version floor"

# The PPA upgrade path must target the tracked floor (DOTFILES_MIN_GIT in
# bootstrap/versions.sh), not a literal that can drift from it.
# shellcheck disable=SC2016  # matching the literal variable reference
assert_contains "$(declare -f _ensure_modern_git_apt)" 'minimum="$DOTFILES_MIN_GIT"' \
    "git upgrade floor comes from bootstrap/versions.sh"
assert_equals "2.48.0" "${DOTFILES_MIN_GIT:-}" \
    "tracked minimum git is 2.48.0 (worktree relative paths)"
assert_contains "$(declare -f _ensure_modern_git_apt)" "relative-paths" \
    "non-Ubuntu warning names the worktree feature"

# ============================================================
# Test Suite: brew / GitHub-release install parity
# ============================================================
test_suite "brew/GitHub install parity"

# The GitHub-release block runs only when the package manager is not brew, so a
# tool listed there and absent from install_brew's formula list is never
# installed on macOS at all. That is how gitleaks shipped missing: the
# pre-commit hook soft-passes when it is not on PATH, so nothing surfaced it.
_brew_formula_for() {
    case "$1" in
        delta) echo "git-delta" ;;
        difft) echo "difftastic" ;;
        sg)    echo "ast-grep" ;;
        *)     echo "$1" ;;
    esac
}

# Bounded by the block's own guard and the comment that closes it, so tools
# installed on brew hosts too (codex and friends) stay out of scope.
_github_tools=$(awk '
    /pkg_mgr" != "brew"/       { inblock = 1 }
    /# Hosts included, unlike/ { inblock = 0 }
    inblock && /install_from_github "/ {
        line = $0
        sub(/.*install_from_github "/, "", line)
        sub(/".*/, "", line)
        print line
    }
' "$DOTFILES_DIR/bootstrap/packages.sh")

_brew_formulas=$(declare -f install_brew | grep -E 'packages\+?=\(' \
    | grep -oE '"[a-z0-9-]+"' | tr -d '"')

# Guard against a refactor that breaks extraction and makes the loop vacuous.
_tool_count=$(printf '%s\n' "$_github_tools" | grep -c .)
if [ "$_tool_count" -ge 15 ]; then _extracted=yes; else _extracted=no; fi
assert_equals "yes" "$_extracted" \
    "GitHub-release block extraction found tools (got $_tool_count)"

_missing=""
while IFS= read -r _tool; do
    [ -n "$_tool" ] || continue
    _formula=$(_brew_formula_for "$_tool")
    if ! printf '%s\n' "$_brew_formulas" | grep -qx "$_formula"; then
        _missing="$_missing $_tool"
    fi
done <<< "$_github_tools"

assert_equals "" "$_missing" \
    "every GitHub-release tool has a brew formula in install_brew"

# ============================================================
# Summary
# ============================================================
print_test_summary
