#!/usr/bin/env bash
# Behavioral coverage for the cross-harness read-only glab API classifier.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$DOTFILES_DIR/agent-hooks/pre-forge-api-readonly.sh"

source "$SCRIPT_DIR/test-framework.sh"

run_hook() {
    local event="$1" command="$2" payload
    payload=$(jq -n -c --arg event "$event" --arg command "$command" \
        '{hook_event_name:$event,tool_name:"Bash",tool_input:{command:$command}}')
    printf '%s' "$payload" | bash "$HOOK"
}

assert_falls_through() {
    local event="$1" command="$2" message="$3"
    assert_equals "" "$(run_hook "$event" "$command")" "$message"
}

test_suite "Claude PreToolUse approval"

output=$(run_hook PreToolUse "glab api projects/:fullpath/releases")
assert_equals "allow" \
    "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision')" \
    "Claude allows a REST GET"
assert_equals "PreToolUse" \
    "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.hookEventName')" \
    "Claude receives the PreToolUse response shape"

test_suite "Codex PermissionRequest approval"

output=$(run_hook PermissionRequest "glab api projects --paginate")
assert_equals "allow" \
    "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.decision.behavior')" \
    "Codex allows a REST GET"
assert_equals "PermissionRequest" \
    "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.hookEventName')" \
    "Codex receives the PermissionRequest response shape"

test_suite "REST classification"

assert_falls_through PreToolUse "glab api projects -f name=changed" \
    "Fields without an explicit GET fall through"
assert_equals "allow" \
    "$(run_hook PreToolUse "glab api projects -X GET -f search=term" | jq -r '.hookSpecificOutput.permissionDecision')" \
    "Fields on an explicit GET are allowed as query parameters"
assert_falls_through PreToolUse "glab api projects -X DELETE" \
    "DELETE falls through"
assert_falls_through PreToolUse "glab api projects --method=PATCH" \
    "PATCH falls through"
assert_falls_through PreToolUse "glab api projects --input request.json" \
    "An uninspectable input body falls through"
assert_falls_through PreToolUse "glab api projects -X GET -F query=@request.json" \
    "An explicit GET cannot read query data from a file"
assert_falls_through PreToolUse "glab api projects -H 'X-HTTP-Method-Override: DELETE'" \
    "An HTTP method override header falls through"
assert_falls_through PreToolUse "glab api projects --output" \
    "A paired flag without a value falls through"
assert_falls_through PreToolUse "glab api projects/:id/variables" \
    "A CI/CD variable read remains approval-gated"
assert_falls_through PreToolUse "glab api projects/:id/terraform/state/production" \
    "An OpenTofu state read remains approval-gated"
assert_falls_through PreToolUse "glab api projects/:id/secure_files/42/download" \
    "A secure-file download remains approval-gated"

test_suite "GraphQL classification"

# shellcheck disable=SC2016  # GraphQL variable, not a shell expansion.
query_command='glab api graphql -f query='"'"'query($endCursor: String) {
  project(fullPath: "group/project") { name }
}'"'"' --paginate'
assert_equals "allow" \
    "$(run_hook PermissionRequest "$query_command" | jq -r '.hookSpecificOutput.decision.behavior')" \
    "A multi-line GraphQL query is allowed"
assert_falls_through PermissionRequest \
    "glab api graphql -f 'query=mutation { issueCreate(input: {}) { issue { id } } }'" \
    "A GraphQL mutation falls through"
assert_falls_through PermissionRequest \
    "glab api graphql -f 'query=query { currentUser { username } }' -f 'query=query { projects { nodes { name } } }'" \
    "Duplicate GraphQL query fields fall through"
assert_falls_through PermissionRequest \
    "glab api graphql -f 'query=query { project(fullPath: \"group/project\") { ciVariables { nodes { value } } } }'" \
    "A GraphQL CI/CD variable read remains approval-gated"

test_suite "Shell and scope safety"

newline_command='glab api projects --output
./deploy'
assert_falls_through PreToolUse "$newline_command" \
    "A literal newline cannot smuggle a second command"
assert_falls_through PreToolUse "glab api projects; ./deploy" \
    "A command separator falls through"
assert_falls_through PreToolUse "glab api projects*" \
    "An unquoted glob falls through"
assert_falls_through PreToolUse "gh repo view cli/cli" \
    "Stable gh reads are left to declarative rules"
assert_falls_through PreToolUse "glab api 'https://example.com/collect?x=1'" \
    "A full URL endpoint falls through"
assert_falls_through PreToolUse "glab api projects/1/../../user" \
    "A path traversal segment falls through"
assert_falls_through PreToolUse "glab mr view 42" \
    "Stable glab reads are left to declarative rules"
assert_falls_through OtherEvent "glab api projects" \
    "Unknown hook events cannot grant approval"

test_suite "Forge reads with local output processing"

assert_allowed() {
    local command="$1" message="$2"
    assert_equals "allow" \
        "$(run_hook PreToolUse "$command" | jq -r '.hookSpecificOutput.permissionDecision')" \
        "$message"
}

assert_allowed "glab api projects/:id/jobs/42/trace | rg -n -i 'localhost:8080|rollback' | head -25" \
    "A GET piped through rg and head is allowed"
assert_allowed "glab api 'projects/:id/pipelines?per_page=100&ref=main' | jq -c '[.[] | select(.status == \"failed\")] | length'" \
    "A jq filter may use brackets, braces, parentheses and quoted pipes"
assert_allowed "glab api --paginate 'projects/:id/merge_requests?state=all' > /tmp/fixture/mrs.json" \
    "A GET redirected to one literal path is allowed"
assert_allowed "glab api projects/:id/deployments | jq -r '.[].sha' | sort | uniq -c | wc -l" \
    "Several read-only filters may be chained"
# shellcheck disable=SC2016  # GraphQL variable, not a shell expansion.
assert_allowed 'glab api graphql -f query='"'"'query { project(fullPath: "group/project") { name } }'"'"' > /tmp/fixture/gql.json' \
    "A read-only GraphQL query may be redirected to a literal path"
assert_contains \
    "$(run_hook PreToolUse "glab api projects | jq -r .name > /tmp/fixture/out.json" | jq -r '.hookSpecificOutput.permissionDecisionReason')" \
    "piped to jq written to /tmp/fixture/out.json" \
    "The approval reason names the filters and the redirect target"

test_suite "Repo scope, native jq filter and stderr discards"

assert_allowed "glab api -R group/project 'projects/:id/pipelines?per_page=100' --paginate" \
    "A -R repo override is a scope flag, not a request body"
assert_allowed "glab api --repo group/project projects/:id/deployments | jq -r '.[].sha'" \
    "A --repo override is allowed in a pipeline"
assert_allowed "glab api projects/:id/pipelines/42/jobs --jq '.[] | select(.status != \"success\") | .id'" \
    "glab's native --jq output filter cannot alter the request"
assert_allowed "glab api projects/:id/pipelines 2>&1 | jq -r '.[].id'" \
    "Merging stderr into stdout before a filter is allowed"
assert_allowed "glab api projects/:id/pipelines 2>/dev/null | jq -r '.[].id'" \
    "Discarding stderr before a filter is allowed"
assert_allowed "glab api -R group/project projects/:id/jobs/42/trace 2>&1 | rg -n error | head -20" \
    "Scope flag, stderr merge and filters combine"
assert_falls_through PreToolUse "glab api -R" \
    "A repo flag without a value falls through"
assert_falls_through PreToolUse "glab api -R group/project projects -X DELETE" \
    "A repo flag does not relax the method check"

assert_falls_through PreToolUse "glab api projects | sed -i s/a/b/ notes.md" \
    "A mutating filter falls through"
assert_falls_through PreToolUse "glab api projects | xargs glab api -X DELETE" \
    "xargs cannot launder a write through the pipeline"
assert_falls_through PreToolUse "glab api projects | tee /etc/hosts" \
    "tee is not a read-only filter"
assert_falls_through PreToolUse "glab api projects | jq . ; rm -rf x" \
    "A separator after a filter falls through"
assert_falls_through PreToolUse "glab api projects || glab mr create --fill" \
    "A logical OR falls through"
assert_falls_through PreToolUse "glab api projects | jq \"\$(cat filter.jq)\"" \
    "Command substitution inside a filter falls through"
# shellcheck disable=SC2016  # The literal $TMPDIR is the point of the test.
assert_falls_through PreToolUse 'glab api projects > "$TMPDIR/out.json"' \
    "A redirect target with shell expansion falls through"
assert_falls_through PreToolUse "glab api projects >> /tmp/fixture/out.json" \
    "An append redirect falls through"
assert_falls_through PreToolUse "glab api projects 2>/tmp/fixture/err.log | jq ." \
    "An fd-numbered redirect to a file falls through"
assert_falls_through PreToolUse "glab api projects 1>/dev/null | jq ." \
    "A stdout fd redirect falls through"
assert_falls_through PreToolUse "glab api projects 2>&1x | jq ." \
    "A stderr redirect glued to trailing text falls through"
assert_falls_through PreToolUse "glab api projects > /tmp/fixture/a.json > /tmp/fixture/b.json" \
    "A second redirect falls through"
assert_falls_through PreToolUse "glab api projects -X POST | jq ." \
    "A pipeline does not relax the method check"
assert_falls_through PreToolUse "glab api projects/:id/variables | jq ." \
    "A pipeline does not relax the secret-endpoint check"
assert_falls_through PreToolUse "glab api projects | jq . | bash" \
    "A shell at the end of the pipeline falls through"

test_suite "gh api read-only requests"

assert_allowed "gh api repos/{owner}/{repo}/releases" \
    "gh's own endpoint placeholders pass the strict scan"
assert_allowed "gh api 'repos/cli/cli/pulls?state=open&per_page=100' --paginate --jq '.[].number'" \
    "A quoted query string with --paginate and --jq is allowed"
assert_allowed "gh api -X GET search/issues -f q='repo:cli/cli is:open'" \
    "Fields on an explicit GET are query parameters"
assert_allowed "gh api -H 'Accept: application/vnd.github.raw+json' repos/cli/cli/contents/README.md" \
    "An Accept header does not alter the method"
assert_allowed 'gh api repos/{owner}/{repo}/issues --template '"'"'{{range .}}{{.title}}{{end}}'"'"'' \
    "A quoted Go template only shapes output"
assert_allowed "gh api --cache 1h -p nebula repos/o/r" \
    "Cache and preview flags are allowed"
assert_allowed "gh api repos/o/r/actions/runs/42/jobs 2>/dev/null | jq -r '.jobs[].name' | sort > /tmp/fixture/jobs.txt" \
    "gh shares the stderr, pipeline and redirect rules"
# shellcheck disable=SC2016  # GraphQL variables, not shell expansions.
assert_allowed 'gh api graphql -F owner='"'"'{owner}'"'"' -F name='"'"'{repo}'"'"' -f query='"'"'query($name: String!, $owner: String!) { repository(owner: $owner, name: $name) { id } }'"'"'' \
    "A GraphQL query with placeholder variables is allowed"
assert_equals "allow" \
    "$(run_hook PermissionRequest "gh api user" | jq -r '.hookSpecificOutput.decision.behavior')" \
    "Codex allows a gh REST GET"
assert_contains \
    "$(run_hook PreToolUse "gh api user" | jq -r '.hookSpecificOutput.permissionDecisionReason')" \
    "read-only gh api GET user" \
    "The approval reason names the tool"

test_suite "gh api requests that keep the prompt"

assert_falls_through PreToolUse "gh api repos/{owner}/{repo}/issues/1/comments -f body=hi" \
    "Fields without an explicit GET fall through"
assert_falls_through PreToolUse "gh api repos/o/r -X DELETE" \
    "DELETE falls through"
assert_falls_through PreToolUse "gh api repos/o/r/issues --input body.json" \
    "An uninspectable input body falls through"
assert_falls_through PreToolUse "gh api gists -X GET -F 'files[a.txt][content]=@notes.txt'" \
    "An explicit GET cannot read field data from a file"
assert_falls_through PreToolUse "gh api graphql -f 'query=mutation { addStar(input: {}) { clientMutationId } }'" \
    "A GraphQL mutation falls through"
assert_falls_through PreToolUse "gh api repos/o/r/secret-scanning/alerts" \
    "Secret-scanning alerts remain approval-gated"
assert_falls_through PreToolUse "gh api repos/o/r/hooks/1/config" \
    "Webhook configuration remains approval-gated"
assert_falls_through PreToolUse "gh api app/hook/config" \
    "App webhook configuration remains approval-gated"
assert_falls_through PreToolUse "gh api orgs/o/actions/variables" \
    "Actions variables remain approval-gated"
assert_falls_through PreToolUse "gh api 'https://example.com/collect?x=1'" \
    "A full URL endpoint falls through"
assert_falls_through PreToolUse "gh api repos/o/r/../../user" \
    "A path traversal segment falls through"
assert_falls_through PreToolUse "gh api repos/{owner,repo}/releases" \
    "A brace expansion is not a gh placeholder"
assert_falls_through PreToolUse "glab api projects/{owner}/releases" \
    "gh placeholders are not relaxed for glab"
assert_falls_through PreToolUse "gh api --hostname example.com 'repos/o/r?x=1'" \
    "A gh host override is an egress channel and falls through"
assert_falls_through PreToolUse "glab api --hostname example.com 'projects?x=1'" \
    "A glab host override is an egress channel and falls through"
assert_falls_through PreToolUse "gh api repos/o/r --verbose" \
    "--verbose prints request headers and falls through"
assert_falls_through PreToolUse "gh api -R o/r repos/o/r" \
    "glab's repo flag is not a gh flag"
assert_falls_through PreToolUse "gh api repos/o/r | tee out.txt" \
    "gh pipelines accept only read-only filters"

test_suite "Filter option boundaries"

assert_allowed "gh api user | jq -rc --arg label login '{label: \$label, value: .login}' | head -n 10" \
    "Combined jq flags and two-argument options retain one-call filtering"
assert_allowed "gh api user | rg -ni -m2 --regexp login | cut -d: -f2 | sort -ru | uniq -c | wc -l" \
    "Common short flags, attached values and filters compose"
assert_allowed "gh api user | grep -E --regexp 'login|name' | tail --lines=5" \
    "Long flags and equals values are supported"
assert_allowed "gh api user | sort -o /tmp/fixture/sorted.json" \
    "Local output files are independent of the Forge-write gate"
assert_allowed "gh api user | uniq - /tmp/fixture/unique.json" \
    "A filter's positional output file is allowed"
assert_allowed "gh api user | rg -e --pre" \
    "An execution-option spelling used as a pattern is data"
assert_allowed "gh api user | rg -- --pre" \
    "The option terminator makes later arguments data"

for filter in \
    "rg --pre /tmp/fixture/processor login /tmp/fixture/input" \
    "rg --pre=/tmp/fixture/processor login /tmp/fixture/input" \
    "rg login /tmp/fixture/input --pre /tmp/fixture/processor" \
    "rg -z login" \
    "rg -niz login" \
    "rg --search-zip login" \
    "sort --compress-program=/tmp/fixture/processor" \
    "sort --compress-program /tmp/fixture/processor" \
    "sort --compress-prog=/tmp/fixture/processor" \
    "rg --future-option login" \
    "jq --arg label" \
    "head -n"; do
    assert_falls_through PreToolUse "gh api user | $filter" \
        "Unsupported or incomplete filter keeps the prompt: $filter"
done

assert_falls_through PreToolUse "gh api user | rg *" \
    "Glob expansion cannot introduce execution options"
assert_falls_through PreToolUse "gh api user | rg --{pre,regexp}=processor" \
    "Brace expansion cannot introduce execution options"
assert_falls_through PreToolUse 'gh api user | rg \\"x' \
    "Unquoted escapes fall through instead of confusing shell quote tracking"
assert_falls_through PreToolUse 'gh api user | rg "\\\\"; gh api user -X DELETE #"' \
    "An escaped backslash does not hide a closing quote and second command"
assert_allowed 'gh api user | jq "\\\\"' \
    "An escaped backslash inside balanced quotes remains data"

test_suite "CLI request interpretation"

for tool in gh glab; do
    assert_allowed "$tool api user --method=GET --raw-field=page=1" \
        "$tool explicit GET overrides the field-induced POST default"
    assert_allowed "$tool api user -X GET --method GET" \
        "$tool repeated read methods are allowed"
    assert_falls_through PreToolUse "$tool api user -X GET --method DELETE" \
        "$tool a later write method cannot override an approved GET"
    assert_falls_through PreToolUse "$tool api user -X DELETE --method GET" \
        "$tool mixed methods conservatively keep the prompt"
    assert_falls_through PreToolUse "$tool api user --raw-field=body=hello" \
        "$tool equals-form fields still imply POST"
    assert_falls_through PreToolUse "$tool api user --method=GET --input=body.json" \
        "$tool equals-form input remains uninspectable"
    assert_falls_through PreToolUse "$tool api user -H 'X-HTTP-Method: DELETE'" \
        "$tool alternative method-override header keeps the prompt"
    assert_falls_through PreToolUse "$tool api user --header='x-http-method-override: PATCH'" \
        "$tool equals-form method-override header keeps the prompt"
    assert_allowed "$tool api graphql -f 'query=query One { viewer { login } } query Two { viewer { id } }' -f operationName=Two" \
        "$tool named operation selection among queries remains read-only"
    assert_falls_through PreToolUse "$tool api graphql -f 'query=query Read { viewer { id } } mutation Write { deleteIssue(input: {}) { clientMutationId } }' -f operationName=Write" \
        "$tool selecting a mutation after a query keeps the prompt"
    assert_falls_through PreToolUse "$tool api graphql -f 'query=query { viewer { id } }' -F 'query=mutation { deleteIssue(input: {}) { clientMutationId } }'" \
        "$tool duplicate query flags cannot replace the inspected operation"
    assert_falls_through PreToolUse "$tool api user --form body=hello" \
        "$tool form fields cannot introduce a POST"
done

print_test_summary
