# Data Model: Unattended Harness

## Devcontainer rubric (`unattended/devcontainer-rubric.json`)

The rubric is the authoritative rule set consumed by `dc-audit.sh`. It
is JSON; one top-level key per concern, each with a list of rules.

### Top-level shape

```json
{
  "version": "1.0",
  "profiles": {
    "attended":   { "rules": ["..."] },
    "unattended": { "rules": ["..."] }
  },
  "rules": {
    "<rule-id>": { ... rule definition ... }
  }
}
```

### Rule definition

Each rule has:

| Field            | Type              | Description                                                                                          |
|------------------|-------------------|------------------------------------------------------------------------------------------------------|
| `id`             | string (kebab)    | Stable identifier; used in JSONL output.                                                             |
| `severity`       | `info \| warn \| error` | Severity reported by dc-audit; `--strict` exits non-zero on warn or higher.                          |
| `description`    | string            | Human-readable description shown in audit output.                                                    |
| `applies_to`     | array of strings  | JSONPath-like selectors against the devcontainer.json (e.g. `runArgs`, `image`, `mounts`).           |
| `check`          | string            | Predicate name (one of: `contains`, `pattern_match`, `forbids_pattern`, `is_pinned`, `array_contains_all`). |
| `check_args`     | object            | Predicate-specific arguments.                                                                         |
| `fix_expression` | string \| null    | jq expression that, when applied with `jq -e`, produces a fixed devcontainer.json. Null = no auto-fix. |
| `tags`           | array of strings  | Free-form tags for filtering (e.g. `security`, `resource-cap`, `lifecycle`).                          |

### Example rule

```json
{
  "id": "no-new-privileges",
  "severity": "warn",
  "description": "runArgs must include --security-opt=no-new-privileges",
  "applies_to": ["runArgs"],
  "check": "array_contains_all",
  "check_args": { "values": ["--security-opt=no-new-privileges"] },
  "fix_expression": ".runArgs += [\"--security-opt=no-new-privileges\"]",
  "tags": ["security", "unattended"]
}
```

### Profile selection

A profile lists which rules to apply:

```json
{
  "profiles": {
    "attended": {
      "rules": [
        "image-pinned",
        "image-required",
        "features-pinned",
        "shutdown-action",
        "wait-for-declared",
        "update-remote-user-uid",
        "no-new-privileges",
        "runargs-privileged",
        "runargs-cap-sys-admin",
        "runargs-seccomp-unconfined",
        "host-creds-mount-attended",
        "docker-sock-mount",
        "broad-home-mount",
        "fixed-env-in-containerenv"
      ]
    },
    "unattended": {
      "rules": [
        "image-pinned",
        "image-required",
        "features-pinned",
        "shutdown-action",
        "wait-for-declared",
        "update-remote-user-uid",
        "no-new-privileges",
        "runargs-privileged",
        "runargs-cap-sys-admin",
        "runargs-seccomp-unconfined",
        "pids-limit-unattended",
        "memory-cap-unattended",
        "cpu-cap-unattended",
        "cap-drop-unattended",
        "no-host-creds-unattended",
        "docker-sock-mount",
        "broad-home-mount",
        "fixed-env-in-containerenv"
      ]
    }
  }
}
```

The unattended profile is not a strict superset of attended: a few
rules are profile-specific (`host-creds-mount-attended` warns when an
attended profile mounts host credentials; `no-host-creds-unattended`
errors when an unattended profile does the same; the resource-cap
rules apply only to unattended). The shared rules cover image
pinning, lifecycle, privilege flags, and the docker-socket / broad-
home-mount footguns.

## Egress allowlist (`unattended/egress-allowlist.txt`)

Plain text; one hostname per line; `#` for comments. mitmproxy reads
the file at startup.

### Categories of allowed hosts

| Category                   | Example hosts                                                              | Why                                                                  |
|----------------------------|---------------------------------------------------------------------------|----------------------------------------------------------------------|
| Anthropic API              | `api.anthropic.com`, `claude.ai`                                          | Claude Code itself.                                                  |
| GitHub                     | `github.com`, `api.github.com`, `objects.githubusercontent.com`           | gh, git push/pull, ralph cloning + pushing.                          |
| Package registries         | `pypi.org`, `files.pythonhosted.org`, `registry.npmjs.org`, `crates.io`,  `proxy.golang.org`, `sum.golang.org` | Dependency installs.                                                |
| OS package mirrors         | `archive.ubuntu.com`, `security.ubuntu.com`, `dl-cdn.alpinelinux.org`     | apt-get / apk add (used by unattended-deps.sh).                      |
| GitHub Container Registry  | `ghcr.io`                                                                 | Pulling base images for nested testing.                              |
| Vulnerability data         | `osv.dev`, `nvd.nist.gov`                                                 | osv-scanner queries.                                                 |

### Format

```
# Anthropic
api.anthropic.com
claude.ai

# GitHub
github.com
api.github.com
objects.githubusercontent.com

# ... etc
```

No ports, no paths -- mitmproxy applies allowlisting at the host level.
Lines starting with `#` and blank lines are skipped.

## Iteration progress (`progress.txt` in workspace)

ralph reads and writes `progress.txt` at the workspace root each
iteration. Free-form text but with conventional sections:

```
# Progress

## Done
- T001 Set up project skeleton
- T002 Wire database connection

## Doing
- T003 Implement login endpoint

## Blocked
- T005 (waiting on test fixture from QA)

## Learnings
- Pytest's monkeypatch is needed for the database mock; the simple
  fixture-replacement approach didn't work because the code uses a
  module-level cache.

## Last verify result
- 2026-05-08T14:32:01Z PASS (`make test`)
```

ralph parses this loosely -- no rigid schema -- but the "Learnings"
section is critical: ralph's prompt template instructs Claude to read
learnings before planning, so accumulated knowledge from prior
iterations doesn't get lost.

## PRD frontmatter (`PRD.md` consumed by ralph)

YAML frontmatter parsed by `unattended/scripts/ralph-spec.sh`:

```yaml
---
title: "Login feature"
verify: "make test"
session_budget: 5
max_wall_clock_seconds: 14400
circuit_breaker_threshold: 3
tasks:
  - id: T001
    description: "Add login endpoint"
    verify: "pytest tests/test_login.py::test_endpoint"
  - id: T002
    description: "Add session store"
    verify: "pytest tests/test_session.py"
---
```

Top-level fields:

| Field                          | Required | Description                                                       |
|--------------------------------|----------|-------------------------------------------------------------------|
| `title`                        | yes      | Feature name shown in commit messages.                            |
| `verify`                       | yes      | Default verify command (run when no per-task verify).             |
| `session_budget`               | no       | Max sessions; default 10.                                         |
| `max_wall_clock_seconds`       | no       | Total budget; default 14400 (4h).                                 |
| `circuit_breaker_threshold`    | no       | Stalls before exit; default 3.                                    |
| `tasks`                        | no       | List of `{id, description, verify}`. If absent, ralph plans freely. |
