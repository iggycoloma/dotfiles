# Spec: GitHub Repository Policy Profiles

Date: 2026-04-11
Status: Draft
Scope: Reusable command-line tooling for applying standardized GitHub repository governance profiles to repos where the user has admin access.

## Problem

Many repositories need the same baseline GitHub settings: protect `main`, require pull requests, keep linear history, prefer squash merges, require Conventional Commit-style PR titles, and still keep solo/admin repos practical. Doing this through the GitHub UI is slow, inconsistent, and hard to reproduce across many repos.

## Goals

- Provide three reusable profiles: `solo`, `team`, and `strict`.
- Use GitHub repository rulesets instead of classic branch protection.
- Configure repository merge settings consistently from the command line.
- Add semantic PR-title enforcement with GitHub Actions.
- Make the workflow executable with `gh` against any `OWNER/REPO` where the user is an admin.
- Support dry-run output before applying changes.

## Non-Goals

- Do not auto-migrate every existing repo.
- Do not enforce topic branch naming in v1.
- Do not replace repo-specific CI workflows.
- Do not create organization-wide rulesets in v1.
- Do not require CODEOWNERS except in the `strict` profile.

## Proposed Command

Create a reusable helper:

```bash
bin/gh-repo-policy [options] OWNER/REPO
```

Proposed options:

```text
--profile <solo|team|strict>       Policy profile to apply. Default: solo.
--branch <name>                    Protected/default branch. Default: main.
--checks <a,b,c>                   Additional required status check names.
--no-semantic-workflow             Do not install/update semantic PR-title workflow.
--no-semantic-required-check       Do not require semantic PR-title check in ruleset.
--ruleset-name <name>              Override managed ruleset name.
--dry-run                          Print commands/payloads without applying.
-h, --help                         Show help.
```

Example usage:

```bash
bin/gh-repo-policy --profile solo iggycoloma/dotfiles
bin/gh-repo-policy --profile team --checks "Shellcheck,Test" acme/service-api
bin/gh-repo-policy --profile strict --checks "Shellcheck,Test,Security" acme/critical-service
bin/gh-repo-policy --profile solo --dry-run iggycoloma/example
```

Required local tools:

- `gh`
- `jq`
- `base64`

Required GitHub permissions:

- repository admin access for the target repo
- for fine-grained tokens, repository Administration write permission for repository rulesets

## Repository Settings

The helper should configure these repo-level settings through `gh repo edit`:

```text
Default branch: main
Squash merge: enabled
Merge commits: disabled
Rebase merge: disabled
Auto-merge: enabled
Delete branch on merge: enabled
Allow update branch: enabled
Squash commit message: PR title and description
```

Rationale:

- Squash-only keeps `main` readable.
- PR title becomes the squash commit title.
- Semantic PR-title enforcement gives Conventional Commit-style commits on `main`.
- Auto-delete keeps branch lists clean.
- Allow-update-branch lets maintainers refresh stale PRs easily.

## Profile Definitions

### `solo`

Use for personal repos and solo-admin maintenance.

```text
Pull request required for main: yes
Required approving reviews: 1
Dismiss stale reviews on push: yes
Require last push approval: no
Require CODEOWNERS review: no
Require conversation resolution: yes
Require linear history: yes
Block force pushes: yes
Block branch deletion: yes
Require semantic PR-title check: yes
Additional required checks: optional
Require signed commits: no
Admin bypass: yes, pull-request mode only if supported
```

Intent:

- Normal collaborators must use PRs and reviews.
- Admin/owner can keep solo repos moving practically.
- Admin bypass should preserve a PR audit trail where rulesets support pull-request-only bypass.

### `team`

Use for collaborative repos.

```text
Pull request required for main: yes
Required approving reviews: 1
Dismiss stale reviews on push: yes
Require last push approval: no
Require CODEOWNERS review: no
Require conversation resolution: yes
Require linear history: yes
Block force pushes: yes
Block branch deletion: yes
Require semantic PR-title check: yes
Additional required checks: recommended
Require signed commits: no
Admin bypass: no
```

Intent:

- Admins follow the same merge path as contributors.
- CI checks should usually be required.
- Avoid high-friction settings unless the repo needs them.

### `strict`

Use for high-risk, production-critical, or mature team repos.

```text
Pull request required for main: yes
Required approving reviews: 2
Dismiss stale reviews on push: yes
Require last push approval: yes
Require CODEOWNERS review: yes
Require conversation resolution: yes
Require linear history: yes
Block force pushes: yes
Block branch deletion: yes
Require semantic PR-title check: yes
Additional required checks: required in practice
Require signed commits: yes
Admin bypass: no
Require status checks to be up to date: yes
```

Intent:

- Strong governance over convenience.
- Best for repos with clear ownership and stable CI.
- Should not be the default for solo repos.

## Ruleset Design

Use a managed repository ruleset targeting the default branch:

```text
Target: branch
Enforcement: active
Condition include: refs/heads/main
Condition exclude: none
Managed ruleset name: Dotfiles standard: main protection
```

Rules to include:

```text
Deletion protection
Non-fast-forward protection
Required linear history
Required pull request
Required status checks
Required signatures, strict profile only
```

Pull request rule parameters should map to the selected profile:

```text
required_approving_review_count
require_code_owner_review
dismiss_stale_reviews_on_push
require_last_push_approval
required_review_thread_resolution
allowed_merge_methods: squash only
```

Status checks:

- Always include `Semantic PR title` unless disabled.
- Include additional checks from `--checks`.
- Use non-strict required checks for `solo` and `team` by default.
- Use strict required checks for `strict`.

Admin bypass:

- `solo`: allow repository admin bypass in pull-request mode if supported by the ruleset API.
- `team`: no bypass.
- `strict`: no bypass.

## Semantic PR Title Enforcement

The helper should install or update this workflow in the target repo:

```text
.github/workflows/pr-title.yml
```

Workflow behavior:

- Trigger on `pull_request_target` title-relevant events.
- Validate PR titles against Conventional Commits.
- Require the job name `Semantic PR title`.
- Do not check out code in this workflow.

Proposed workflow:

```yaml
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
    name: Semantic PR title
    runs-on: ubuntu-latest
    steps:
      - uses: step-security/action-semantic-pull-request@v6
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
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
```

Valid PR titles:

```text
feat: add repo policy helper
fix(dotfiles): correct git include doctor check
docs: document branch protection profiles
ci: require semantic PR title
refactor!: remove legacy install path
```

Security note:

- `pull_request_target` is appropriate for title-only validation because it runs with base-repo context.
- Do not add checkout, build, script execution, or dependency installation to this workflow.
- Consider pinning the action to a full commit SHA later for stricter supply-chain posture.

## Branch Naming Convention

Document but do not enforce initially.

Recommended branch patterns:

```text
feat/<short-slug>
fix/<short-slug>
docs/<short-slug>
chore/<short-slug>
refactor/<short-slug>
test/<short-slug>
ci/<short-slug>
deps/<package-or-area>
security/<short-slug>
```

Examples:

```text
feat/add-gh-repo-policy
fix/dotfiles-doctor-git-include-check
docs/update-support-matrix
ci/add-fedora-container-test
deps/update-github-cli-install
```

Rationale:

- Naming convention is useful for humans and searchability.
- Enforcing topic branch names across many repos adds friction.
- Revisit enforcement only if branch naming drift becomes a real problem.

## Implementation Plan

### Phase 1: Documentation/spec only

- Add this spec to `planning/`.
- Confirm profile semantics before writing code.

### Phase 2: Add executable helper

- Create `bin/gh-repo-policy`.
- Implement argument parsing.
- Implement `--dry-run`.
- Validate local dependencies.
- Parse `OWNER/REPO`.

### Phase 3: Repository settings

- Use `gh repo edit` for merge settings.
- Ensure squash-only behavior.
- Enable branch cleanup and auto-merge.

### Phase 4: Semantic PR-title workflow

- Generate workflow content internally or from a template file.
- Use GitHub Contents API through `gh api` to create/update `.github/workflows/pr-title.yml`.
- Use a conventional commit message such as `ci: add semantic PR title check`.

### Phase 5: Ruleset create/update

- Use `gh api` with repository rulesets endpoints.
- Search existing rulesets by managed name.
- Create if missing.
- Update if present.
- Print final summary.

### Phase 6: Validation

- Run `bash -n bin/gh-repo-policy`.
- Run `shellcheck bin/gh-repo-policy`.
- Run a dry-run against a sample repo name.
- Apply to a non-critical test repo first.
- Open a test PR with both valid and invalid PR titles.

## Edge Cases

### Required checks may not exist yet

GitHub may not fully recognize a check until the workflow has run at least once. If this causes friction:

- first run with `--no-semantic-required-check`
- open a PR to trigger the check
- rerun the policy helper to require the check

### Existing rulesets

The helper should manage only the ruleset matching its configured name. It should not delete unrelated rulesets.

### Existing semantic workflow

If `.github/workflows/pr-title.yml` already exists, update it only if the user explicitly runs the helper. Future versions may add `--no-overwrite-workflow` if needed.

### Admin bypass expectations

GitHub does not allow PR authors to approve their own PRs. The solo profile should support practicality through admin bypass, not self-approval.

### CODEOWNERS in strict mode

`strict` requires CODEOWNERS review. If a repo has no CODEOWNERS file, this can create confusing behavior. The helper should warn when applying `strict` that CODEOWNERS should exist.

## Acceptance Criteria

- A user can run one command to apply `solo`, `team`, or `strict` to `OWNER/REPO`.
- The target repo is configured for squash-only merges.
- The target repo has a ruleset protecting `main` according to the selected profile.
- The semantic PR title workflow is present unless disabled.
- The semantic PR title check is required unless disabled.
- Dry-run mode shows intended changes without modifying the repo.
- The implementation is documented and shellcheck-clean.

## Open Questions

1. Should `solo` require any CI checks by default beyond `Semantic PR title`.
2. Should the helper install a CODEOWNERS stub for `strict` or only warn.
3. Should action references be pinned to tags initially or full commit SHAs.
4. Should branch naming enforcement become an optional second ruleset later.
5. Should this eventually support organization rulesets in addition to repository rulesets.

## Source References

- GitHub rulesets overview:
  - https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets
- GitHub ruleset rules:
  - https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
- GitHub REST API for repository rulesets:
  - https://docs.github.com/en/rest/repos/rules
- GitHub CLI `repo edit` manual:
  - https://cli.github.com/manual/gh_repo_edit
- GitHub merge methods:
  - https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/about-merge-methods-on-github
- GitHub required reviews and self-approval behavior:
  - https://docs.github.com/articles/approving-a-pull-request-with-required-reviews
- Semantic PR title action:
  - https://github.com/step-security/action-semantic-pull-request
