#!/usr/bin/env bash
# Approve Forge reads with supported output processing, including local writes.
# Local filesystem containment belongs to the execution environment.
# Wired to Claude PreToolUse; the Codex response shape is available but unwired.
set -euo pipefail

payload=$(cat)
command=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')
hook_event=$(printf '%s' "$payload" | jq -r '.hook_event_name // empty')
[ -n "$command" ] || exit 0

python3 - "$hook_event" "$command" <<'PYEOF'
import json
import re
import shlex
import sys
from urllib.parse import unquote

hook_event = sys.argv[1]
cmd = sys.argv[2]


def deny():
    # No matching permission rule: leave the decision to the harness.
    sys.exit(0)


def allow(reason):
    if hook_event == "PermissionRequest":
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PermissionRequest",
                "decision": {"behavior": "allow"},
            }
        }
    elif hook_event == "PreToolUse":
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "permissionDecisionReason": reason,
            }
        }
    else:
        deny()
    print(json.dumps(output))
    sys.exit(0)


# Shell expansion could introduce arguments that the classifier never sees.
STRICT = "$`|;&<>()\r\n*?[]{}\\#"


def scan(segment, forbidden):
    in_single = in_double = False
    escaped = False
    for ch in segment:
        if in_single:
            if ch == "'":
                in_single = False
        elif in_double:
            if ch in "$`":
                deny()
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_double = False
        else:
            if ch == "'":
                in_single = True
            elif ch == '"':
                in_double = True
            elif ch in forbidden:
                deny()
    if in_single or in_double:
        deny()


STDERR_DISCARD_TARGETS = ("&1", "/dev/null")


def stderr_discard_target(current, rest):
    """Return the target of a standalone `2>&1` or `2>/dev/null`, else None.

    Only stderr redirected into stdout or discarded is accepted: neither can
    write a file, and both are how glab's TLS and update chatter gets silenced
    in front of a filter. Every other fd-numbered redirect stays denied.
    """
    if not current or current[-1] != "2":
        return None
    if len(current) > 1 and not current[-2].isspace():
        return None
    for target in STDERR_DISCARD_TARGETS:
        if rest.startswith(target):
            after = rest[len(target):]
            if after and not after[0].isspace() and after[0] != "|":
                deny()
            return target
    return None


def split_pipeline(raw):
    """Split on top-level `|` and detach one trailing `> path` redirect.

    Returns (segments, redirect_path). Denies on `||`, `|&`, `>>`, fd-numbered
    redirects other than `2>&1` and `2>/dev/null`, `<`, `;`, `&`, backticks and
    unquoted `$`, so the only shell structure that survives is
    `glab api ... [2>&1] | filter ... [> literal-path]`.
    """
    segments = []
    current = []
    redirect = None
    in_single = in_double = False
    escaped = False
    i = 0
    while i < len(raw):
        ch = raw[i]
        nxt = raw[i + 1] if i + 1 < len(raw) else ""
        if in_single:
            if ch == "'":
                in_single = False
            current.append(ch)
        elif in_double:
            if ch in "$`":
                deny()
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_double = False
            current.append(ch)
        else:
            if ch == "'":
                in_single = True
                current.append(ch)
            elif ch == '"':
                in_double = True
                current.append(ch)
            elif ch == "|":
                if nxt in "|&":
                    deny()
                segments.append("".join(current))
                current = []
            elif ch == ">":
                stderr_target = stderr_discard_target(current, raw[i + 1:])
                if stderr_target is not None:
                    current.pop()
                    i += 1 + len(stderr_target)
                    continue
                if nxt == ">" or redirect is not None:
                    deny()
                if current and current[-1].isdigit():
                    deny()
                segments.append("".join(current))
                redirect = raw[i + 1:]
                break
            elif ch in "$`;&<\r\n\\#":
                deny()
            else:
                current.append(ch)
        i += 1
    else:
        segments.append("".join(current))
    if in_single or in_double:
        deny()
    if redirect is not None:
        redirect = redirect.strip()
        if not redirect or any(c in redirect for c in "$`|;&<>()*?[]{}\"' \t\r\n"):
            deny()
    return [s.strip() for s in segments], redirect


def options(bare, paired="", double=""):
    return {**dict.fromkeys(bare.split(), 0),
            **dict.fromkeys(paired.split(), 1),
            **dict.fromkeys(double.split(), 2)}


# Enumerate supported options rather than guessing which future flags can spawn
# programs (rg --pre/--search-zip and sort --compress-program already can).
FILTER_OPTIONS = {
    "jq": options(
        "-c -r -j -s -R -n -e -a -S -M -C --compact-output --raw-output "
        "--join-output --slurp --raw-input --null-input --exit-status "
        "--ascii-output --sort-keys --monochrome-output --color-output "
        "--tab --unbuffered --stream --seq",
        "--indent", "--arg --argjson --slurpfile --rawfile"),
    "rg": options(
        "-i -s -S -v -n -N -c -l -L -w -x -F -o -q -a -U -P "
        "--ignore-case --case-sensitive --smart-case --invert-match "
        "--line-number --no-line-number --count --count-matches "
        "--files-with-matches --files-without-match --word-regexp "
        "--line-regexp --fixed-strings --only-matching --quiet --text "
        "--multiline --multiline-dotall --pcre2 --no-heading --heading "
        "--no-filename --with-filename --no-config --no-pre --no-search-zip",
        "-e -f -m -A -B -C -g -t -T -r --regexp --file --max-count "
        "--after-context --before-context --context --glob --type --type-not "
        "--replace --color --max-columns --max-filesize --encoding"),
    "grep": options(
        "-i -v -n -c -l -L -w -x -F -E -G -P -o -q -s -a -h -H "
        "--ignore-case --invert-match --line-number --count "
        "--files-with-matches --files-without-match --word-regexp "
        "--line-regexp --fixed-strings --extended-regexp --basic-regexp "
        "--perl-regexp --only-matching --quiet --silent --no-messages "
        "--text --no-filename --with-filename",
        "-e -f -m -A -B -C --regexp --file --max-count --after-context "
        "--before-context --context"),
    "head": options("-q -v --quiet --silent --verbose", "-n -c --lines --bytes"),
    "tail": options("-q -v --quiet --silent --verbose", "-n -c --lines --bytes"),
    "wc": options("-l -w -c -m -L --lines --words --bytes --chars --max-line-length"),
    "sort": options(
        "-b -d -f -g -h -i -M -n -r -s -u -V -z --ignore-leading-blanks "
        "--dictionary-order --ignore-case --general-numeric-sort "
        "--human-numeric-sort --ignore-nonprinting --month-sort "
        "--numeric-sort --reverse --stable --unique --version-sort --zero-terminated",
        "-k -t -o -S -T --key --field-separator --output --buffer-size "
        "--temporary-directory --parallel --batch-size"),
    "uniq": options(
        "-c -d -u -i -z --count --repeated --unique --ignore-case --zero-terminated",
        "-f -s -w --skip-fields --skip-chars --check-chars"),
    "cut": options("-s -z --only-delimited --zero-terminated --complement",
                   "-b -c -f -d --bytes --characters --fields --delimiter --output-delimiter"),
}


def check_filter(tokens):
    if not tokens or tokens[0] not in FILTER_OPTIONS:
        deny()
    supported = FILTER_OPTIONS[tokens[0]]
    i = 1
    while i < len(tokens):
        token = tokens[i]
        if token == "--":
            return
        if token == "-" or not token.startswith("-"):
            i += 1
            continue
        if tokens[0] in ("head", "tail") and re.fullmatch(r"-\d+", token):
            i += 1
            continue
        consumed = 0
        if token.startswith("--"):
            flag, equals, _ = token.partition("=")
            if flag not in supported or (equals and supported[flag] == 0):
                deny()
            consumed = supported[flag] - bool(equals)
        else:
            for offset, short in enumerate(token[1:], 2):
                flag = "-" + short
                if flag not in supported:
                    deny()
                if supported[flag]:
                    consumed = supported[flag] - (offset < len(token))
                    break
        if i + consumed >= len(tokens):
            deny()
        i += 1 + consumed

segments, redirect = split_pipeline(cmd)
if not segments or not segments[0]:
    deny()

# gh substitutes these itself, and without a comma or `..` the shell leaves the
# braces literal, so they are neutralized for the strict scan rather than
# relaxing it for every brace.
GH_ENDPOINT_PLACEHOLDERS = ("{owner}", "{repo}", "{branch}")

strictly_scanned = segments[0]
if strictly_scanned.split(None, 1)[0] == "gh":
    for placeholder in GH_ENDPOINT_PLACEHOLDERS:
        strictly_scanned = strictly_scanned.replace(placeholder, "_")
scan(strictly_scanned, STRICT)
for segment in segments[1:]:
    scan(segment, STRICT)
    try:
        filter_tokens = shlex.split(segment)
    except ValueError:
        deny()
    check_filter(filter_tokens)

try:
    tokens = shlex.split(segments[0])
except ValueError:
    deny()

# Output-shaping and scope flags that cannot alter the request. Both tools run
# outside the sandbox, so --hostname is left out: with an endpoint it sends an
# arbitrary path and query string to an arbitrary host. gh's --verbose is left
# out because it prints the full request, headers included.
NON_REQUEST_FLAGS = {
    "glab": {
        "paired": {"-H", "--header", "--output", "-R", "--repo", "--jq"},
        "bare": {"--paginate", "-i", "--include", "--silent"},
    },
    "gh": {
        "paired": {"-H", "--header", "-q", "--jq", "-t", "--template",
                   "--cache", "-p", "--preview"},
        "bare": {"--paginate", "--slurp", "-i", "--include", "--silent"},
    },
}

if len(tokens) < 3 or tokens[0] not in NON_REQUEST_FLAGS or tokens[1] != "api":
    deny()

tool = tokens[0]
args = tokens[2:]

# Field flags supply a request body; on REST they also flip the method to
# POST. --input reads a body from a file or stdin we cannot inspect.
BODY_FLAGS = {"-f", "-F", "--field", "--raw-field"}
GH_SENSITIVE_SEGMENTS = {"secret-scanning", "hooks", "hook", "variables"}
PAIRED_FLAGS = NON_REQUEST_FLAGS[tool]["paired"]
BARE_FLAGS = NON_REQUEST_FLAGS[tool]["bare"]

endpoint = None
fields = []
headers = []
method = None
i = 0
while i < len(args):
    tok = args[i]
    if tok in ("-X", "--method"):
        if i + 1 >= len(args) or args[i + 1].upper() != "GET":
            deny()
        method = "GET"
        i += 2
    elif tok.startswith("--method="):
        if tok.split("=", 1)[1].upper() != "GET":
            deny()
        method = "GET"
        i += 1
    elif tok in BODY_FLAGS:
        if i + 1 >= len(args):
            deny()
        fields.append(args[i + 1])
        i += 2
    elif "=" in tok and tok.split("=", 1)[0] in BODY_FLAGS:
        fields.append(tok.split("=", 1)[1])
        i += 1
    elif tok in BARE_FLAGS:
        i += 1
    elif tok in PAIRED_FLAGS:
        if i + 1 >= len(args):
            deny()
        if tok in ("-H", "--header"):
            headers.append(args[i + 1])
        i += 2
    elif "=" in tok and tok.split("=", 1)[0] in PAIRED_FLAGS:
        flag, value = tok.split("=", 1)
        if not value:
            deny()
        if flag in ("-H", "--header"):
            headers.append(value)
        i += 1
    elif tok.startswith("-"):
        deny()  # unrecognized flag, including --input
    elif endpoint is None:
        endpoint = tok
        i += 1
    else:
        deny()

if endpoint is None:
    deny()
if "://" in endpoint:
    deny()  # A full URL can carry a query string to any host.

for field in fields:
    if "=" not in field:
        deny()
    _, value = field.split("=", 1)
    if value.startswith("@") or value == "-":
        deny()  # Never auto-approve reading request data from a file or stdin.

for header in headers:
    name = header.split(":", 1)[0].strip().lower()
    if name in ("x-http-method-override", "x-method-override", "x-http-method"):
        deny()

if endpoint == "graphql":
    # Query fields normally imply POST; the operation decides whether it writes.
    query = None
    for field in fields:
        key, value = field.split("=", 1)
        if key == "query":
            if query is not None:
                deny()
            query = value
    if query is None:
        deny()
    stripped = query.lstrip()
    if not (stripped.startswith("query") or stripped.startswith("{")):
        deny()
    if re.search(r"\bmutation\b", query):
        deny()
    if re.search(r"\b(ciVariables|rawBlob|terraformState|secureFiles)\b", query):
        deny()  # Queries likely to return secrets or protected file contents.
    reason = f"read-only {tool} api graphql query"
else:
    if fields and method != "GET":
        deny()  # REST fields imply POST unless GET was explicit.
    decoded_path = unquote(endpoint.split("?", 1)[0]).lower()
    path_segments = decoded_path.strip("/").split("/")
    if ".." in path_segments:
        deny()
    if tool == "glab":
        sensitive = ("/variables" in decoded_path
                     or "/terraform/state" in decoded_path
                     or ("/secure_files/" in decoded_path
                         and decoded_path.endswith("/download")))
    else:
        # Secret-scanning alerts return the leaked secret in plaintext, webhook
        # configs often embed a token in the delivery URL, and Actions
        # variables mirror the GitLab CI/CD variable gate.
        sensitive = not GH_SENSITIVE_SEGMENTS.isdisjoint(path_segments)
    if sensitive:
        deny()
    reason = f"read-only {tool} api GET {endpoint}"

if len(segments) > 1:
    reason += " piped to " + " | ".join(s.split()[0] for s in segments[1:])
if redirect:
    reason += f" written to {redirect}"
allow(reason)
PYEOF
