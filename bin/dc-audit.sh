#!/usr/bin/env bash
set -euo pipefail

# dc-audit.sh -- Audit devcontainer.json files against a best-practices rubric.
#
# Works standalone in any repo. Reads agentic/devcontainer-rubric.json from
# the repo or from the deployed ~/.agentic/ location (or a --rubric path) and
# evaluates each rule against the target file(s).
#
# devcontainer.json is valid JSON with comments (JSONC). Comments are stripped
# before jq parsing so the tool does not choke on real-world files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve DOTFILES_DIR (dev checkout or deployed) for logging + default rubric.
if [[ -f "$SCRIPT_DIR/../bootstrap/logging.sh" ]]; then
    DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [[ -f "${DOTFILES_DIR:-}/bootstrap/logging.sh" ]]; then
    :
else
    echo "Error: cannot locate bootstrap/logging.sh" >&2
    exit 1
fi

# shellcheck source=../bootstrap/logging.sh
source "$DOTFILES_DIR/bootstrap/logging.sh"

# --- Defaults ---

PROFILE="attended"
RUBRIC=""
FIX=false
STRICT=false
JSON_OUTPUT=false
TARGETS=()

# --- Help ---

show_help() {
    cat <<'HELP'
Usage: dc-audit.sh [options] [PATH ...]

Audit devcontainer.json files against the dotfiles best-practices rubric.

If no PATH is given, auto-detects .devcontainer/**/devcontainer.json in the
current directory.

Options:
  --profile <attended|unattended>  Rubric profile (default: attended)
  --rubric <path>                  Override rubric JSON location
  --fix                            Apply safe, additive auto-fixes in place
  --strict                         Exit non-zero if any finding at warn or error
  --json                           Emit findings as JSONL (one object per finding)
  -h, --help                       Show this help

Examples:
  dc-audit.sh                                         # audit everything under .devcontainer/
  dc-audit.sh --profile unattended .devcontainer/ci/devcontainer.json
  dc-audit.sh --fix .devcontainer/unattended/devcontainer.json
  dc-audit.sh --strict --json .devcontainer/*/devcontainer.json
HELP
}

# --- Dependency checks ---

check_dependencies() {
    command -v jq &>/dev/null || log_and_return error 1 "Missing required tool: jq"
}

# --- Argument parsing ---

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile)
                PROFILE="${2:?--profile requires a value}"
                case "$PROFILE" in
                    attended|unattended) ;;
                    *) log_error "--profile must be 'attended' or 'unattended'"; return 1 ;;
                esac
                shift 2
                ;;
            --rubric)
                RUBRIC="${2:?--rubric requires a value}"
                shift 2
                ;;
            --fix)
                FIX=true
                shift
                ;;
            --strict)
                STRICT=true
                shift
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                return 1
                ;;
            *)
                TARGETS+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$RUBRIC" ]]; then
        for candidate in \
            "$DOTFILES_DIR/agentic/devcontainer-rubric.json" \
            "$HOME/.agentic/devcontainer-rubric.json"
        do
            if [[ -f "$candidate" ]]; then
                RUBRIC="$candidate"
                break
            fi
        done
        if [[ -z "$RUBRIC" ]]; then
            log_error "Rubric not found. Pass --rubric, or deploy agentic/ via DOTFILES_INSTALL_AGENTIC=1 ./install.sh."
            return 1
        fi
    fi

    if [[ ! -f "$RUBRIC" ]]; then
        log_error "Rubric file not found: $RUBRIC"
        return 1
    fi

    if [[ ${#TARGETS[@]} -eq 0 ]]; then
        local found=()
        while IFS= read -r -d '' f; do
            found+=("$f")
        done < <(find .devcontainer -name 'devcontainer.json' -type f -print0 2>/dev/null)
        if [[ ${#found[@]} -eq 0 ]]; then
            log_error "No targets given and no .devcontainer/**/devcontainer.json found."
            return 1
        fi
        TARGETS=("${found[@]}")
    fi
}

# --- JSONC support ---
#
# devcontainer.json permits // line comments and /* block comments. Strip them
# before feeding to jq. We avoid hard-matching quoted strings (a real parser
# would handle them) -- the strip is intentionally conservative and may leave
# a `//` inside a URL intact, which is fine since jq can parse that too.

strip_jsonc() {
    local path="$1"
    # Remove /* ... */ blocks and // line comments that begin a line or follow
    # whitespace. This regex avoids eating `://` in strings.
    sed -e 's|/\*[^*]*\*\+\([^/*][^*]*\*\+\)*/||g' \
        -e 's|^\s*//.*$||' \
        -e 's|\s\+//.*$||' \
        "$path"
}

# --- Core: evaluate rules ---
#
# For each rule in the rubric (matching the active profile or "all"), run the
# jq `check` expression. `check` returns true when the rule FAILS. When fix
# mode is on and the rule is fixable, apply the jq `fix` to produce the new
# document.
#
# Prints findings to stdout in human-readable or JSONL form.

declare -A FINDING_COUNTS

audit_file() {
    local file="$1"
    local stripped
    stripped=$(strip_jsonc "$file")

    # Validate JSON first.
    if ! jq empty <<<"$stripped" 2>/dev/null; then
        print_finding "$file" "parse-error" "error" "File is not valid JSON/JSONC." "no"
        return 2
    fi

    # Iterate rules matching the active profile.
    local rule_count=0
    local applied_fixes=0
    rule_count=$(jq --arg p "$PROFILE" \
        '[.rules[] | select(.profile == $p or .profile == "all")] | length' \
        "$RUBRIC")

    local idx
    for (( idx=0; idx<rule_count; idx++ )); do
        local rule id severity message check fixable fix
        rule=$(jq --arg p "$PROFILE" --argjson i "$idx" \
            '[.rules[] | select(.profile == $p or .profile == "all")][$i]' \
            "$RUBRIC")
        id=$(jq -r '.id' <<<"$rule")
        severity=$(jq -r '.severity' <<<"$rule")
        message=$(jq -r '.message' <<<"$rule")
        check=$(jq -r '.check' <<<"$rule")
        fixable=$(jq -r '.fixable // false' <<<"$rule")
        fix=$(jq -r '.fix // empty' <<<"$rule")

        local failed
        failed=$(jq "$check" <<<"$stripped" 2>/dev/null || echo "false")
        if [[ "$failed" != "true" ]]; then
            continue
        fi

        if [[ "$FIX" == true ]] && [[ "$fixable" == "true" ]] && [[ -n "$fix" ]]; then
            # Apply fix to the stripped JSON, then overwrite the source file.
            # We write pure JSON; comments are not preserved (acceptable for
            # devcontainer.json in practice). Pretty-print with 2-space indent.
            local fixed
            if fixed=$(jq "$fix" <<<"$stripped" 2>/dev/null); then
                printf '%s\n' "$fixed" > "$file"
                stripped="$fixed"
                applied_fixes=$((applied_fixes + 1))
                print_finding "$file" "$id" "$severity" "$message" "fixed"
            else
                print_finding "$file" "$id" "$severity" "$message" "fix-failed"
            fi
            continue
        fi

        print_finding "$file" "$id" "$severity" "$message" "$fixable"
    done

    if [[ "$FIX" == true ]] && [[ $applied_fixes -gt 0 ]]; then
        log_info "Applied $applied_fixes fix(es) to $file"
    fi
}

print_finding() {
    local file="$1" id="$2" severity="$3" message="$4" status="$5"

    # Fixed findings are no longer findings -- do not count them toward the
    # error/warn totals that drive --strict. Track them separately.
    case "$status" in
        fixed)
            FINDING_COUNTS[fixed]=$(( ${FINDING_COUNTS[fixed]:-0} + 1 ))
            ;;
        *)
            FINDING_COUNTS[$severity]=$(( ${FINDING_COUNTS[$severity]:-0} + 1 ))
            ;;
    esac

    if [[ "$JSON_OUTPUT" == true ]]; then
        jq -cn \
            --arg file "$file" \
            --arg id "$id" \
            --arg severity "$severity" \
            --arg message "$message" \
            --arg status "$status" \
            '{file: $file, rule: $id, severity: $severity, message: $message, status: $status}'
        return
    fi

    local prefix
    case "$severity" in
        error) prefix="ERROR" ;;
        warn)  prefix="WARN " ;;
        info)  prefix="INFO " ;;
        *)     prefix="$severity" ;;
    esac

    local suffix=""
    case "$status" in
        fixed)      suffix=" [fixed]" ;;
        fix-failed) suffix=" [fix FAILED]" ;;
        "true")     suffix=" [fixable; rerun with --fix]" ;;
    esac

    printf '  %s %-30s %s: %s%s\n' "$prefix" "[$id]" "$file" "$message" "$suffix"
}

# --- Main ---

main() {
    parse_args "$@"
    check_dependencies

    log_section "dc-audit: profile=$PROFILE  rubric=$RUBRIC"

    local overall_rc=0
    for target in "${TARGETS[@]}"; do
        if [[ ! -f "$target" ]]; then
            log_error "Target not found: $target"
            overall_rc=1
            continue
        fi
        audit_file "$target" || overall_rc=$?
    done

    local errors=${FINDING_COUNTS[error]:-0}
    local warns=${FINDING_COUNTS[warn]:-0}
    local infos=${FINDING_COUNTS[info]:-0}
    local fixed=${FINDING_COUNTS[fixed]:-0}

    if [[ "$JSON_OUTPUT" != true ]]; then
        log_section "Summary"
        printf '  Files checked: %s\n' "${#TARGETS[@]}"
        printf '  Errors:   %s\n' "$errors"
        printf '  Warnings: %s\n' "$warns"
        printf '  Info:     %s\n' "$infos"
        [[ "$FIX" == true ]] && printf '  Fixed:    %s\n' "$fixed"
    fi

    # Exit policy:
    #   errors -> always non-zero
    #   warns (and above) -> non-zero when --strict
    if [[ $errors -gt 0 ]]; then
        return 1
    fi
    if [[ "$STRICT" == true ]] && [[ $warns -gt 0 ]]; then
        return 1
    fi
    return "$overall_rc"
}

# Allow sourcing for testing without executing main.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
