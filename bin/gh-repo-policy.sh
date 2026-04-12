#!/usr/bin/env bash
set -euo pipefail

# gh-repo-policy.sh -- Apply standardized GitHub repository governance profiles.
# Configures branch protection (rulesets), merge strategy, and semantic PR titles.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../bootstrap/logging.sh
source "$DOTFILES_DIR/bootstrap/logging.sh"

# --- Constants ---

readonly SEMANTIC_ACTION_REF="amannn/action-semantic-pull-request@0723387faaf9b38adef4775cd42cfd5155ed6017"
readonly SEMANTIC_CHECK_NAME="Semantic PR title"

# --- Defaults ---

PROFILE="solo"
BRANCH="main"
CHECKS=""
INSTALL_WORKFLOW=true
REQUIRE_SEMANTIC_CHECK=true
RULESET_NAME=""
DRY_RUN=false
FORCE=false
REPO=""

# --- Help ---

show_help() {
    cat <<'HELP'
Usage: gh-repo-policy.sh [options] OWNER/REPO

Apply a standardized GitHub repository governance profile.

Profiles:
  solo    Personal/solo-admin repos (default). Admin bypass enabled.
  team    Collaborative repos. No admin bypass.
  strict  Production-critical repos. 2 reviewers, signed commits, CODEOWNERS.

Options:
  --profile <solo|team|strict>       Policy profile (default: solo)
  --branch <name>                    Protected branch (default: main)
  --checks <a,b,c>                   Additional required status check names
  --no-semantic-workflow             Skip installing semantic PR title workflow
  --no-semantic-required-check       Do not require semantic PR title in ruleset
  --ruleset-name <name>              Override managed ruleset name
  --force                             Apply changes even if settings differ from current
  --dry-run                          Print intended changes without applying
  -h, --help                         Show this help

Examples:
  gh-repo-policy.sh --profile solo user/dotfiles
  gh-repo-policy.sh --profile team --checks "Lint,Test" org/service
  gh-repo-policy.sh --profile strict --checks "Lint,Test,Security" org/critical
  gh-repo-policy.sh --profile solo --dry-run user/example
HELP
}

# --- Dependency checks ---

check_dependencies() {
    local missing=()
    for cmd in gh jq base64; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        return 1
    fi
}

# --- Argument parsing ---

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile)
                PROFILE="${2:?--profile requires a value}"
                shift 2
                ;;
            --branch)
                BRANCH="${2:?--branch requires a value}"
                shift 2
                ;;
            --checks)
                CHECKS="${2:?--checks requires a value}"
                shift 2
                ;;
            --no-semantic-workflow)
                INSTALL_WORKFLOW=false
                shift
                ;;
            --no-semantic-required-check)
                REQUIRE_SEMANTIC_CHECK=false
                shift
                ;;
            --ruleset-name)
                RULESET_NAME="${2:?--ruleset-name requires a value}"
                shift 2
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
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
                if [[ -n "$REPO" ]]; then
                    log_error "Unexpected argument: $1 (OWNER/REPO already set to $REPO)"
                    return 1
                fi
                REPO="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$REPO" ]]; then
        log_error "Missing required argument: OWNER/REPO"
        show_help
        return 1
    fi

    if [[ ! "$REPO" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid OWNER/REPO format: $REPO"
        return 1
    fi

    case "$PROFILE" in
        solo|team|strict) ;;
        *)
            log_error "Invalid profile: $PROFILE (must be solo, team, or strict)"
            return 1
            ;;
    esac
}

# --- Validate repo access ---

validate_repo() {
    local repo="$1"
    log_info "Validating admin access to $repo"

    local perms
    if ! perms=$(gh api "repos/$repo" --jq '.permissions.admin' 2>/dev/null); then
        log_error "Cannot access repository: $repo"
        return 1
    fi

    if [[ "$perms" != "true" ]]; then
        log_error "You do not have admin access to $repo"
        return 1
    fi

    log_success "Admin access confirmed for $repo"
}

# --- Repository settings ---

# Fields we manage -- used for both building payloads and diffing
readonly REPO_SETTINGS_FIELDS='[
    "allow_squash_merge",
    "allow_merge_commit",
    "allow_rebase_merge",
    "allow_auto_merge",
    "delete_branch_on_merge",
    "allow_update_branch",
    "squash_merge_commit_title",
    "squash_merge_commit_message"
]'

build_repo_settings_payload() {
    local profile="$1"
    local allow_rebase=false
    if [[ "$profile" == "team" ]]; then
        allow_rebase=true
    fi
    jq -n --argjson rebase "$allow_rebase" '{
        allow_squash_merge: true,
        allow_merge_commit: false,
        allow_rebase_merge: $rebase,
        allow_auto_merge: true,
        delete_branch_on_merge: true,
        allow_update_branch: true,
        squash_merge_commit_title: "PR_TITLE",
        squash_merge_commit_message: "PR_BODY"
    }'
}

diff_repo_settings() {
    local repo="$1"
    local proposed="$2"

    local current
    current=$(gh api "repos/$repo" --jq \
        "{allow_squash_merge, allow_merge_commit, allow_rebase_merge,
          allow_auto_merge, delete_branch_on_merge, allow_update_branch,
          squash_merge_commit_title, squash_merge_commit_message}" 2>/dev/null) || return 1

    local diffs
    diffs=$(jq -n \
        --argjson current "$current" \
        --argjson proposed "$proposed" \
        --argjson fields "$REPO_SETTINGS_FIELDS" \
        '[$fields[] | select($current[.] != $proposed[.]) |
            {field: ., current: $current[.], proposed: $proposed[.]}]')

    local count
    count=$(echo "$diffs" | jq 'length')

    if [[ "$count" -eq 0 ]]; then
        log_success "Repository settings already match $PROFILE profile"
        return 0
    fi

    log_warn "Repository settings differ from $PROFILE profile:"
    echo "$diffs" | jq -r '.[] | "  \(.field): \(.current) -> \(.proposed)"'

    if [[ "$FORCE" == true ]]; then
        return 1  # signal "has changes, proceed"
    else
        log_error "Run with --force to apply these changes"
        return 2  # signal "has changes, blocked"
    fi
}

apply_repo_settings() {
    local repo="$1"
    log_section "Repository Settings"

    local payload
    payload=$(build_repo_settings_payload "$PROFILE")

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[dry-run] PATCH repos/$repo"
        echo "$payload" | jq .
        return 0
    fi

    local diff_rc=0
    diff_repo_settings "$repo" "$payload" || diff_rc=$?

    case $diff_rc in
        0) return 0 ;;          # no changes needed
        2) return 1 ;;          # changes exist, --force not set
        1) ;;                   # changes exist, --force set -- proceed
    esac

    gh api "repos/$repo" \
        --method PATCH \
        --input - <<< "$payload" > /dev/null
    log_success "Repository merge settings applied"
}

# --- Semantic PR title workflow ---

build_workflow_content() {
    cat <<WORKFLOW
name: PR Title

on:
  pull_request_target:
    types:
      - opened
      - edited
      - reopened
      - synchronize

permissions:
  pull-requests: read

jobs:
  semantic-pr-title:
    name: ${SEMANTIC_CHECK_NAME}
    runs-on: ubuntu-latest
    steps:
      - uses: ${SEMANTIC_ACTION_REF}
        env:
          GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}
        with:
          types: |
            feat
            fix
            docs
            style
            refactor
            perf
            test
            build
            ci
            chore
            revert
          requireScope: false
          subjectPattern: ^(?![A-Z]).+
          subjectPatternError: |
            The subject must not start with an uppercase letter.
WORKFLOW
}

install_semantic_workflow() {
    local repo="$1"
    log_section "Semantic PR Title Workflow"

    if [[ "$INSTALL_WORKFLOW" != true ]]; then
        log_info "Skipping workflow installation (--no-semantic-workflow)"
        return 0
    fi

    local workflow_path=".github/workflows/pr-title.yml"
    local content
    content=$(build_workflow_content | base64 | tr -d '\n')

    # Check if the file already exists on the default branch
    local existing_sha=""
    local existing_content=""
    local existing_json
    if existing_json=$(gh api "repos/$repo/contents/$workflow_path" 2>/dev/null); then
        existing_sha=$(echo "$existing_json" | jq -r '.sha')
        existing_content=$(echo "$existing_json" | jq -r '.content' | base64 -d 2>/dev/null | base64 | tr -d '\n')
    fi

    # If the file exists and content matches, skip
    if [[ -n "$existing_sha" ]] && [[ "$existing_content" == "$content" ]]; then
        log_success "Semantic PR title workflow already up to date"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        if [[ -n "$existing_sha" ]]; then
            log_info "[dry-run] Would update $workflow_path"
        else
            log_info "[dry-run] Would create $workflow_path"
        fi
        return 0
    fi

    local commit_message="ci: add semantic PR title check"
    if [[ -n "$existing_sha" ]]; then
        commit_message="ci: update semantic PR title check"
    fi

    local payload
    payload=$(jq -n \
        --arg message "$commit_message" \
        --arg content "$content" \
        --arg sha "$existing_sha" \
        '{message: $message, content: $content} + (if $sha != "" then {sha: $sha} else {} end)')

    # Try direct commit to default branch
    local api_error
    if api_error=$(gh api "repos/$repo/contents/$workflow_path" \
        --method PUT \
        --input - <<< "$payload" 2>&1); then
        if [[ -n "$existing_sha" ]]; then
            log_success "Semantic PR title workflow updated"
        else
            log_success "Semantic PR title workflow installed"
        fi
        return 0
    fi

    # Diagnose the failure
    if echo "$api_error" | grep -q "workflow"; then
        log_warn "Could not install workflow via API"
        log_warn "GitHub requires the 'workflow' token scope to modify .github/workflows/"
        log_info "To fix, run: gh auth refresh --scopes workflow"
    elif echo "$api_error" | grep -q "pull request"; then
        log_warn "Could not install workflow via API"
        log_warn "Branch protection requires changes via pull request"
        log_info "To fix, run this tool before creating the ruleset on a new repo"
    else
        log_warn "Could not install workflow via API"
        log_info "API error: $(echo "$api_error" | head -1)"
    fi
    log_info ""
    log_info "Add the file manually. Paste this into $workflow_path:"
    log_info ""
    build_workflow_content
    return 1
}

# --- Ruleset ---

build_ruleset_payload() {
    local profile="$1"
    local branch="$2"
    local checks="$3"
    local ruleset_name="$4"

    # Profile-specific settings
    local review_count=1
    local dismiss_stale=true
    local last_push_approval=false
    local codeowner_review=false
    local require_conversation_resolution=true
    local admin_bypass=false
    local bypass_mode="none"
    local require_signatures=false
    local strict_status=false

    local merge_methods='["squash"]'

    case "$profile" in
        solo)
            admin_bypass=true
            bypass_mode="pull_request"
            ;;
        team)
            merge_methods='["squash","rebase"]'
            ;;
        strict)
            review_count=2
            last_push_approval=true
            codeowner_review=true
            require_signatures=true
            strict_status=true
            ;;
    esac

    # Build status checks array
    local status_checks="[]"
    local check_list=()

    if [[ "$REQUIRE_SEMANTIC_CHECK" == true ]]; then
        check_list+=("$SEMANTIC_CHECK_NAME")
    fi

    if [[ -n "$checks" ]]; then
        IFS=',' read -ra extra_checks <<< "$checks"
        for c in "${extra_checks[@]}"; do
            local trimmed
            trimmed=$(echo "$c" | xargs)  # trim whitespace
            [[ -n "$trimmed" ]] && check_list+=("$trimmed")
        done
    fi

    if [[ ${#check_list[@]} -gt 0 ]]; then
        status_checks=$(printf '%s\n' "${check_list[@]}" | jq -R '.' | jq -s '[.[] | {context: .}]')
    fi

    # Build rules array
    local rules
    rules=$(jq -n \
        --argjson review_count "$review_count" \
        --argjson dismiss_stale "$dismiss_stale" \
        --argjson last_push "$last_push_approval" \
        --argjson codeowner "$codeowner_review" \
        --argjson conversation "$require_conversation_resolution" \
        --argjson status_checks "$status_checks" \
        --argjson strict "$strict_status" \
        --argjson merge_methods "$merge_methods" \
        '[
            {type: "deletion"},
            {type: "non_fast_forward"},
            {type: "required_linear_history"},
            {
                type: "pull_request",
                parameters: {
                    required_approving_review_count: $review_count,
                    dismiss_stale_reviews_on_push: $dismiss_stale,
                    require_code_owner_review: $codeowner,
                    require_last_push_approval: $last_push,
                    required_review_thread_resolution: $conversation,
                    allowed_merge_methods: $merge_methods
                }
            },
            {
                type: "required_status_checks",
                parameters: {
                    required_status_checks: $status_checks,
                    strict_required_status_checks_policy: $strict
                }
            }
        ]')

    # Add signature requirement for strict
    if [[ "$require_signatures" == true ]]; then
        rules=$(echo "$rules" | jq '. + [{type: "required_signatures"}]')
    fi

    # Build bypass actors for solo profile
    local bypass_actors="[]"
    if [[ "$admin_bypass" == true ]]; then
        bypass_actors=$(jq -n \
            --arg mode "$bypass_mode" \
            '[{
                actor_id: 5,
                actor_type: "RepositoryRole",
                bypass_mode: $mode
            }]')
    fi

    # Build full payload
    jq -n \
        --arg name "$ruleset_name" \
        --arg branch "$branch" \
        --argjson rules "$rules" \
        --argjson bypass_actors "$bypass_actors" \
        '{
            name: $name,
            target: "branch",
            enforcement: "active",
            conditions: {
                ref_name: {
                    include: ["refs/heads/" + $branch],
                    exclude: []
                }
            },
            rules: $rules,
            bypass_actors: $bypass_actors
        }'
}

find_managed_ruleset() {
    local repo="$1"
    local ruleset_name="$2"

    gh api "repos/$repo/rulesets" 2>/dev/null \
        | jq -r --arg name "$ruleset_name" '.[] | select(.name == $name) | .id' \
        | head -n1 || true
}

diff_ruleset() {
    local repo="$1"
    local ruleset_id="$2"
    local proposed="$3"

    local current
    current=$(gh api "repos/$repo/rulesets/$ruleset_id" 2>/dev/null) || return 1

    # Normalize both to comparable form: pick only the fields we manage
    local comparable_fields='{name, target, enforcement, conditions, rules, bypass_actors}'
    local current_norm proposed_norm
    current_norm=$(echo "$current" | jq "$comparable_fields")
    proposed_norm=$(echo "$proposed" | jq "$comparable_fields")

    if [[ "$(echo "$current_norm" | jq -Sc .)" == "$(echo "$proposed_norm" | jq -Sc .)" ]]; then
        log_success "Ruleset already matches $PROFILE profile"
        return 0
    fi

    log_warn "Ruleset \"$RULESET_NAME\" differs from $PROFILE profile:"
    # Show a compact diff of the two normalized objects
    diff <(echo "$current_norm" | jq -S .) <(echo "$proposed_norm" | jq -S .) \
        | grep '^[<>]' | head -20 | while IFS= read -r line; do
        log_info "  $line"
    done

    if [[ "$FORCE" == true ]]; then
        return 1  # has changes, proceed
    else
        log_error "Run with --force to apply these changes"
        return 2  # has changes, blocked
    fi
}

create_or_update_ruleset() {
    local repo="$1"
    log_section "Repository Ruleset"

    local payload
    payload=$(build_ruleset_payload "$PROFILE" "$BRANCH" "$CHECKS" "$RULESET_NAME")

    local existing_id
    existing_id=$(find_managed_ruleset "$repo" "$RULESET_NAME")

    if [[ "$DRY_RUN" == true ]]; then
        if [[ -n "$existing_id" ]]; then
            log_info "[dry-run] PUT repos/$repo/rulesets/$existing_id (update)"
        else
            log_info "[dry-run] POST repos/$repo/rulesets (create)"
        fi
        log_info "[dry-run] Payload:"
        echo "$payload" | jq .
        return 0
    fi

    if [[ -n "$existing_id" ]]; then
        local diff_rc=0
        diff_ruleset "$repo" "$existing_id" "$payload" || diff_rc=$?

        case $diff_rc in
            0) return 0 ;;      # no changes needed
            2) return 1 ;;      # changes exist, --force not set
            1) ;;               # changes exist, --force set -- proceed
        esac

        gh api "repos/$repo/rulesets/$existing_id" \
            --method PUT \
            --input - <<< "$payload" > /dev/null
        log_success "Ruleset updated (id: $existing_id)"
    else
        gh api "repos/$repo/rulesets" \
            --method POST \
            --input - <<< "$payload" > /dev/null
        log_success "Ruleset created"
    fi
}

# --- CODEOWNERS warning ---

warn_codeowners() {
    local repo="$1"
    if [[ "$PROFILE" != "strict" ]]; then
        return 0
    fi

    local found=false
    for path in "CODEOWNERS" "docs/CODEOWNERS" ".github/CODEOWNERS"; do
        if gh api "repos/$repo/contents/$path" --silent 2>/dev/null; then
            found=true
            break
        fi
    done

    if [[ "$found" != true ]]; then
        log_warn "strict profile requires CODEOWNERS review, but no CODEOWNERS file found"
        log_warn "Add a CODEOWNERS file to define code ownership for review routing"
    fi
}

# --- Summary ---

print_summary() {
    local repo="$1"
    log_section "Summary"
    log_info "Repository: $repo"
    log_info "Profile:    $PROFILE"
    log_info "Branch:     $BRANCH"
    log_info "Ruleset:    $RULESET_NAME"
    if [[ -n "$CHECKS" ]]; then
        log_info "Checks:     $SEMANTIC_CHECK_NAME, $CHECKS"
    elif [[ "$REQUIRE_SEMANTIC_CHECK" == true ]]; then
        log_info "Checks:     $SEMANTIC_CHECK_NAME"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "Dry run -- no changes were applied"
    else
        log_success "All settings applied successfully"
    fi
}

# --- Main ---

main() {
    parse_args "$@"

    # Set default ruleset name based on --branch if not overridden
    if [[ -z "$RULESET_NAME" ]]; then
        RULESET_NAME="protect $BRANCH"
    fi

    log_section "GitHub Repository Policy: $PROFILE"
    log_info "Target: $REPO ($BRANCH)"

    if [[ "$DRY_RUN" == true ]]; then
        log_warn "Dry-run mode enabled"
    fi

    check_dependencies

    if [[ "$DRY_RUN" != true ]]; then
        validate_repo "$REPO"
    fi

    apply_repo_settings "$REPO"
    install_semantic_workflow "$REPO"
    create_or_update_ruleset "$REPO"
    warn_codeowners "$REPO"
    print_summary "$REPO"
}

# Allow sourcing for testing without executing main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
