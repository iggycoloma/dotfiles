#!/usr/bin/env bash
# Lint devcontainer.json files for risky mounts, env pass-through, and port
# forwards that would punch holes in the container boundary. Part of the
# three-tier sandbox model: the container is the isolation boundary inside
# devcontainers, so anything that bridges host secrets or services into the
# container weakens that boundary. See docs/sandbox.md.
#
# Usage:
#   bootstrap/lint-devcontainer.sh [path-to-devcontainer.json ...]
#
# With no args, scans every .devcontainer/*/devcontainer.json under cwd.
#
# Exit codes:
#   0 -- clean (no findings, or warnings only without --strict)
#   1 -- findings present and --strict was passed (or critical findings)
#
# Flags:
#   --strict   exit 1 on any warning
#   --quiet    only print findings, no headers

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

STRICT=0
QUIET=0
PATHS=()
for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        --quiet)  QUIET=1 ;;
        -h|--help)
            sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) PATHS+=("$arg") ;;
    esac
done

if [[ ${#PATHS[@]} -eq 0 ]]; then
    while IFS= read -r f; do
        PATHS+=("$f")
    done < <(find "$DOTFILES_DIR/.devcontainer" -name devcontainer.json -type f 2>/dev/null | sort)
fi

if [[ ${#PATHS[@]} -eq 0 ]]; then
    [[ $QUIET -eq 0 ]] && echo "lint-devcontainer: no devcontainer.json files found"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "lint-devcontainer: jq is required" >&2
    exit 2
fi

# Risky-mount substrings. Anchored to the source side of "source=X,target=Y"
# strings or the source field of object-form mount entries. Match if the
# substring appears anywhere in the source path (so /run/docker.sock catches
# /var/run/docker.sock and similar variants).
RISKY_MOUNT_PATTERNS=(
    "docker.sock"
    "ssh-auth"
    "SSH_AUTH_SOCK"
    "/.ssh"
    "/.aws"
    "/.gnupg"
    "/.azure"
    "/.config/gh"
    "/.config/gcloud"
    "/.kube"
    "/.docker"
)

# Risky env vars in containerEnv / remoteEnv -- credentials that should not
# be exposed to a process tree that may run an untrusted model.
RISKY_ENV_KEYS=(
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "AWS_SESSION_TOKEN"
    "GCP_SERVICE_ACCOUNT_KEY"
    "GOOGLE_APPLICATION_CREDENTIALS"
    "ANTHROPIC_API_KEY"
    "OPENAI_API_KEY"
    "GH_TOKEN"
    "GITHUB_TOKEN"
    "NPM_TOKEN"
)

WARNINGS=0
FILES_CHECKED=0

_print() { [[ $QUIET -eq 0 ]] && echo "$@"; }
_warn() {
    printf 'WARN [%s] %s\n' "$1" "$2"
    WARNINGS=$((WARNINGS + 1))
}
_info() { [[ $QUIET -eq 0 ]] && printf 'INFO [%s] %s\n' "$1" "$2"; }

# Strip JSONC comments before piping to jq. jq does not parse comments.
_strip_jsonc() {
    # Remove // comments (not inside strings) and /* ... */ blocks. Naive
    # but sufficient for devcontainer.json files which do not embed // or
    # /* in string values typically.
    sed -e 's|//.*$||' -e '/\/\*/,/\*\//d' "$1"
}

_check_mounts() {
    local file="$1"
    # Mounts can be either strings ("source=X,target=Y,type=Z") or objects.
    # Normalize both to a flat list of source values.
    local mount_sources
    mount_sources=$(_strip_jsonc "$file" | jq -r '
        (.mounts // [])[] |
        if type == "string"
            then ([splits(",")] |
                  map(select(startswith("source="))) |
                  .[0] // "" |
                  ltrimstr("source="))
        elif type == "object" then (.source // "")
        else "" end
    ' 2>/dev/null || true)

    while IFS= read -r src; do
        [[ -z "$src" ]] && continue
        for pat in "${RISKY_MOUNT_PATTERNS[@]}"; do
            if [[ "$src" == *"$pat"* ]]; then
                _warn "$file" "risky mount source matches '$pat': $src"
            fi
        done
    done <<< "$mount_sources"

    # Informational: presence of dotfiles-state mount when AI tools are not
    # disabled. Helps catch projects that wanted persistence but forgot.
    local has_state
    has_state=$(_strip_jsonc "$file" | jq -r '
        (.mounts // []) | map(tostring) | join(" ") | test("dotfiles-state")
    ' 2>/dev/null || echo "false")
    if [[ "$has_state" == "false" ]]; then
        _info "$file" "no dotfiles-state mount detected -- agent state will not persist across rebuilds"
    fi
}

_check_env() {
    local file="$1"
    local key vals
    for key in "${RISKY_ENV_KEYS[@]}"; do
        vals=$(_strip_jsonc "$file" | jq -r --arg k "$key" '
            ((.containerEnv // {}) + (.remoteEnv // {})) | .[$k] // empty
        ' 2>/dev/null || true)
        if [[ -n "$vals" ]]; then
            _warn "$file" "credential env var passed to container: $key"
        fi
    done
}

_check_forward_ports() {
    local file="$1"
    # Check forwardPorts for the rare 0.0.0.0 bind syntax. Most projects use
    # numeric ports which default to localhost; only flag explicit 0.0.0.0.
    local risky
    risky=$(_strip_jsonc "$file" | jq -r '
        (.forwardPorts // []) | map(tostring) |
        map(select(startswith("0.0.0.0:"))) | .[]
    ' 2>/dev/null || true)
    if [[ -n "$risky" ]]; then
        _warn "$file" "forwardPorts binds to 0.0.0.0 (public): $risky"
    fi
}

_check_settings_drift() {
    # Cross-file drift check: claude-code/settings.json and
    # settings.container.json must match on every key outside .sandbox.
    local host="$DOTFILES_DIR/claude-code/settings.json"
    local cont="$DOTFILES_DIR/claude-code/settings.container.json"
    [[ -f "$host" && -f "$cont" ]] || return 0

    local diff
    diff=$(diff <(jq 'del(.sandbox)' "$host") <(jq 'del(.sandbox)' "$cont") 2>/dev/null || true)
    if [[ -n "$diff" ]]; then
        _warn "claude-code/settings.json" "drift between settings.json and settings.container.json on non-sandbox keys"
        [[ $QUIET -eq 0 ]] && echo "$diff" | head -20
    fi
}

for f in "${PATHS[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "lint-devcontainer: not a file: $f" >&2
        continue
    fi
    _print ""
    _print "lint-devcontainer: $f"
    _check_mounts "$f"
    _check_env "$f"
    _check_forward_ports "$f"
    FILES_CHECKED=$((FILES_CHECKED + 1))
done

_check_settings_drift

_print ""
_print "lint-devcontainer: $FILES_CHECKED file(s) checked, $WARNINGS warning(s)"

if [[ $WARNINGS -gt 0 && $STRICT -eq 1 ]]; then
    exit 1
fi
exit 0
