#!/usr/bin/env bash
# exec-modes.sh -- Verify the executable bit on every tracked file.
#
# Two silent failure modes this catches:
#
#   1. A hook loses its +x. claude-code/settings.json invokes hooks as bare
#      paths with no interpreter ("~/.claude/hooks/pre-security.sh"), and
#      bootstrap/symlinks.sh deploys them by symlink, so the mode committed
#      here is the mode the harness executes. A non-executable pre-security.sh
#      does not block a credential read, it fails to run at all. git skips a
#      non-executable hook in git/hooks/ just as quietly.
#
#   2. A sourced library gains one. install.sh used to run
#      `chmod +x bootstrap/*.sh` on every install, which is how each of those
#      reached 100755 despite nothing ever executing them -- and why a fresh
#      checkout came back dirty after an install.
#
# The rule is NOT "every .sh is executable": most .sh files here are sourced.
# It is: a tracked file must be executable iff it has a `#!` shebang and is not
# listed in NON_EXEC below.
#
# Modes come from the git index, not stat(2). A chmod in the working tree then
# cannot make this pass or fail (CI installs before it tests, and an installer
# is free to chmod a checkout), and the result does not depend on core.fileMode
# on filesystems that drop the bit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolved from this script's own location, deliberately ignoring an ambient
# DOTFILES_DIR that the sibling lint scripts honor. Those only read; this one
# writes to the index under --fix, and an exported DOTFILES_DIR pointing at
# another checkout would silently rewrite that checkout instead of this one.
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../bootstrap/logging.sh
source "$REPO_DIR/bootstrap/logging.sh"

QUIET=false
FIX=false
ERRORS=0

# Shebang-carrying files that must stay non-executable, with the reason each is
# never run as a command. Patterns are bash `[[ == ]]` globs, where `*` spans
# `/`, so a directory entry covers its subdirectories.
NON_EXEC=(
    "shell/*"                        # rc files and libraries, sourced by the shell
    "bootstrap/*"                    # sourced by install.sh, including lib/
    "agent-hooks/shared-patterns.sh" # sourced by the pre-code-no-emoji hooks
    "templates/*"                    # examples a project copies and owns
    "tests/test-*.sh"                # Makefile runs each as `bash tests/...`
    "tests/unit-tests.sh"            # same, and test-framework.sh is sourced
)
# tests/validate-dotfiles.sh is absent on purpose: it is a standalone health
# check a human runs, not a suite the Makefile drives.

usage() {
    cat <<EOF
Usage: exec-modes.sh [--fix] [--quiet]

Verify every tracked file's executable bit against its shebang.

  --fix     Correct the mismatches instead of only reporting them
  --quiet   Suppress the per-file success line; only report mismatches
EOF
}

is_non_exec() {
    local path="$1" glob
    for glob in "${NON_EXEC[@]}"; do
        # Unquoted on purpose: NON_EXEC holds patterns, not literal paths.
        # shellcheck disable=SC2053
        [[ "$path" == $glob ]] && return 0
    done
    return 1
}

has_shebang() {
    [[ "$(git -C "$REPO_DIR" cat-file blob "$1" 2>/dev/null | head -c2)" == '#!' ]]
}

repair() {
    local path="$1" flag="$2"
    chmod "$flag" "$REPO_DIR/$path"
    git -C "$REPO_DIR" update-index "--chmod=$flag" -- "$path"
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --fix)   FIX=true; shift ;;
            --quiet) QUIET=true; shift ;;
            -h|--help) usage; return 0 ;;
            *) log_error "Unknown option: $1"; usage; return 1 ;;
        esac
    done

    local mode sha stage path expected checked=0
    while IFS=$' \t' read -r -d '' mode sha stage path; do
        : "$stage"
        checked=$((checked + 1))

        if has_shebang "$sha" && ! is_non_exec "$path"; then
            expected=100755
        else
            expected=100644
        fi
        [[ "$mode" == "$expected" ]] && continue

        ERRORS=$((ERRORS + 1))
        if [[ "$expected" == 100755 ]]; then
            log_error "$path: has a shebang but is not executable ($mode)"
            [[ "$FIX" == true ]] && repair "$path" +x
        else
            log_error "$path: executable ($mode) but never run as a command"
            [[ "$FIX" == true ]] && repair "$path" -x
        fi
    done < <(git -C "$REPO_DIR" ls-files -s -z)

    if (( ERRORS > 0 )); then
        if [[ "$FIX" == true ]]; then
            log_success "exec-modes: corrected $ERRORS file mode(s) of $checked"
            return 0
        fi
        log_error "exec-modes: $ERRORS of $checked file(s) have the wrong mode (--fix corrects them)"
        return 1
    fi

    [[ "$QUIET" == true ]] || log_success "exec-modes: all $checked tracked file modes correct"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
